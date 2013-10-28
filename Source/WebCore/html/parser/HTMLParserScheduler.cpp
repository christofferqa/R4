/*
 * Copyright (C) 2010 Google, Inc. All Rights Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "config.h"
#include "HTMLParserScheduler.h"

#include "Document.h"
#include "FrameView.h"
#include "HTMLDocumentParser.h"
#include "Page.h"

#include <WebCore/platform/ThreadGlobalData.h>
#include <WebCore/platform/ThreadTimers.h>
#include <WebCore/eventaction/EventActionSchedule.h>

#include <iostream>
#include <string>
#include <sstream>

// defaultParserChunkSize is used to define how many tokens the parser will
// process before checking against parserTimeLimit and possibly yielding.
// This is a performance optimization to prevent checking after every token.
static const int defaultParserChunkSize = 4096;

// defaultParserTimeLimit is the seconds the parser will run in one write() call
// before yielding.  Inline <script> execution can cause it to excede the limit.
// FIXME: We would like this value to be 0.2.
static const double defaultParserTimeLimit = 0.500;

namespace WebCore {

static double parserTimeLimit(Page* page)
{
    // We're using the poorly named customHTMLTokenizerTimeDelay setting.
    if (page && page->hasCustomHTMLTokenizerTimeDelay())
        return page->customHTMLTokenizerTimeDelay();
    return defaultParserTimeLimit;
}

static int parserChunkSize(Page* page)
{
    // FIXME: We may need to divide the value from customHTMLTokenizerChunkSize
    // by some constant to translate from the "character" based behavior of the
    // old LegacyHTMLDocumentParser to the token-based behavior of this parser.
    if (page && page->hasCustomHTMLTokenizerChunkSize())
        return page->customHTMLTokenizerChunkSize();
    return defaultParserChunkSize;
}

HTMLParserScheduler::HTMLParserScheduler(HTMLDocumentParser* parser)
    : m_parser(parser)
    , m_parserTimeLimit(parserTimeLimit(m_parser->document()->page()))
    , m_parserChunkSize(parserChunkSize(m_parser->document()->page()))
    , m_continueNextChunkTimer(this, &HTMLParserScheduler::continueNextChunkTimerFired)
    , m_isSuspendedWithActiveTimer(false)
    , m_continueNextChunkTimerActive(false)
{
    // TODO(WebERA-HB): The EventRacer implementation mentions an exception caused by a network request, should we add this?
}

HTMLParserScheduler::~HTMLParserScheduler()
{
    m_continueNextChunkTimer.stop();
}

void HTMLParserScheduler::continueNextChunkTimerFired(Timer<HTMLParserScheduler>* timer)
{
    ASSERT_UNUSED(timer, timer == &m_continueNextChunkTimer);
    // FIXME: The timer class should handle timer priorities instead of this code.
    // If a layout is scheduled, wait again to let the layout timer run first.
    //if (m_parser->document()->isLayoutTimerActive()) {

    //    updateTimerName(); // WebERA
    //    m_continueNextChunkTimer.startOneShot(0);
    //    m_continueNextChunkTimerActive = true;

    //    return;
    //}

    // WebERA: A timer should always finish its task when called. It can't reschedule itself otherwise the
    // scheduler would think that this timer has been executed and move on - causing a deadlock.

    m_continueNextChunkTimerActive = false;
    m_parser->resumeParsingAfterYield();
}

void HTMLParserScheduler::checkForYieldBeforeScript(PumpSession& session)
{
    // If we've never painted before and a layout is pending, yield prior to running
    // scripts to give the page a chance to paint earlier.
    Document* document = m_parser->document();
    bool needsFirstPaint = document->view() && !document->view()->hasEverPainted();
    if (needsFirstPaint && document->isLayoutTimerActive())
        session.needsYield = true;
}

void HTMLParserScheduler::scheduleForResume()
{
    updateTimerName(); // WebERA
    m_continueNextChunkTimer.startOneShot(0);
    m_continueNextChunkTimerActive = true;
}


void HTMLParserScheduler::suspend()
{
    ASSERT(!m_isSuspendedWithActiveTimer);
    m_isSuspendedWithActiveTimer = true;

    // TODO(WebERA): Warning, we are assuming that the timer is still active and has not been moved into
    // the EventActionRegister. If that is the case then this operation is not safe.
    if (m_continueNextChunkTimer.isActive())
    {
        m_continueNextChunkTimer.stop();
    }
}

void HTMLParserScheduler::resume()
{
    if (!m_isSuspendedWithActiveTimer)
        return;

    m_isSuspendedWithActiveTimer = false;

    // WebERA - we are assuming that the timer was suspended and already contains the correct descriptor
    m_continueNextChunkTimer.startOneShot(0);
}

void HTMLParserScheduler::updateTimerName()
{
    // Convert an unsigned long into a string
    std::stringstream params;
    params << EventActionDescriptor::escapeParam(m_parser->getDocumentUrl());
    params << ",";
    params << m_parser->getTokensSeen();

    EventActionDescriptor descriptor = threadGlobalData().threadTimers().eventActionRegister()->allocateEventDescriptor(
                "HTMLDocumentParser",
                params.str());

    m_continueNextChunkTimer.setEventActionDescriptor(descriptor);

    // Add a happens before relation if we schedule a new fragment because of another action

    // TODO(WebERA-HB): The EventRacer implementation mentions an exception if this is caused by a script, should we still do this?

    // TODO(WebERA-HB):
    //
    // The "lastNetworkAction" happens before relations are a bit too strict.
    //
    // The happens before relation is associated with a
    // parsing event action too early in the parsing event action chain. E.g. if a network event occurs that adds a new chunk of the web page,
    // then the first parsing event action using that chunk of the page should have a happens before relation, and not earlier.
    //
    // Furthermore, the "page loaded" network event action should also have a happens before much later in the chain - notice that this event
    // action has an effect on the number of parse events needed (it can subsume the last parse event action if executed late).


    const EventActionDescriptor currentDescriptor = threadGlobalData().threadTimers().eventActionRegister()->currentEventActionDispatching();

    threadGlobalData().threadTimers().eventActionsHB()->addExplicitArc(
                currentDescriptor,
                descriptor
    );

    // If the current descriptor is a network event, then it should be the same as the "lastNetworkAction" registered by the parser (if any)
    if (strcmp(currentDescriptor.getType(), "NETWORK") == 0) {
        if (!m_parser->getLastNetworkAction().isNull()) {
            ASSERT(m_parser->getLastNetworkAction() == currentDescriptor);
        }

        m_parser->resetLastNetworkAction(); // remove the last network event and prevent it from being added twice
    }

    if (!m_parser->getLastNetworkAction().isNull()) {
        threadGlobalData().threadTimers().eventActionsHB()->addExplicitArc(
                    m_parser->getLastNetworkAction(),
                    descriptor
        );

        m_parser->resetLastNetworkAction();
    }
}

}
