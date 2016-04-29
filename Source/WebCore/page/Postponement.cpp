/*
 * Copyright (C) 2008 Apple Inc. All Rights Reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */

#include "config.h"
#include "Postponement.h"

#include "DOMTimer.h"
#include "InspectorInstrumentation.h"
#include "ScheduledAction.h"
#include "ScriptExecutionContext.h"
#include "UserGestureIndicator.h"
#include <wtf/ActionLogReport.h>
#include <wtf/EventActionDescriptor.h>
#include <wtf/HashSet.h>
#include <wtf/StdLibExtras.h>

#include <string>
#include <sstream>

#include <WebCore/platform/ThreadGlobalData.h>
#include <WebCore/platform/ThreadTimers.h>

using namespace std;

namespace WebCore {

Postponement::Postponement(ScriptExecutionContext* context, PassOwnPtr<ScheduledAction> action)
    : m_action(action)
    , m_context(context)
{
}

Postponement::~Postponement()
{
}

void Postponement::install(ScriptExecutionContext* context, PassOwnPtr<ScheduledAction> action)
{
    std::cout << "Postponement::install" << std::endl;

    // Construct descriptor

    std::string url = action->getCalledUrl().empty() ? std::string("-") : WTF::EventActionDescriptor::escapeParam(action->getCalledUrl());
    WTF::EventActionId calleeEventActionId = HBIsCurrentEventActionValid() ? HBCurrentEventAction() : -1;


    std::stringstream params;
    params << url << ","
           << action->getCalledLine() << ","
           << -1 << "," // the original event action id that triggered this postponement (set by ReplayScheduler)
           << calleeEventActionId << ","
           << Postponement::getNextSameUrlSequenceNumber(url, action->getCalledLine(), calleeEventActionId);

    WTF::EventActionDescriptor descriptor(WTF::TIMER, "Postponement", params.str());

    // Notify register and scheduler

    WebCore::EventActionRegister* eventActionRegister = WebCore::threadGlobalData().threadTimers().eventActionRegister();
    Scheduler* scheduler = ThreadTimers::getScheduler();

    eventActionRegister->registerEventActionHandler(
                descriptor,
                &firePostponementCallback,
                new Postponement(context, action));
    scheduler->postponementScheduled(descriptor, eventActionRegister);

    std::cout << "Postponement::install DONE" << std::endl;
}

std::map<std::string, unsigned int> Postponement::m_nextSameUrlSequenceNumber;

unsigned int Postponement::getNextSameUrlSequenceNumber(const std::string& url, uint line, WTF::EventActionId eventActionId)
{
    std::stringstream ident;
    ident << url << "-" << line << (int)eventActionId;

    std::map<std::string, unsigned int>::iterator iter = Postponement::m_nextSameUrlSequenceNumber.find(ident.str());

    unsigned int id = 0;

    if (iter != Postponement::m_nextSameUrlSequenceNumber.end()) {
        id = (*iter).second;

        (*iter).second++;

    } else {
        Postponement::m_nextSameUrlSequenceNumber.insert(std::pair<std::string, unsigned int>(ident.str(), 1));
    }

    return id;
}

bool Postponement::firePostponementCallback(void* object, const WTF::EventActionDescriptor&) {
    Postponement* postponement = (Postponement*)object;
    postponement->fired();

    return true;
}

void Postponement::fired()
{
    std::cout << "Postponement::fired()" << std::endl;

    // ScriptExecutionContext* context = scriptExecutionContext();
    m_action->execute(m_context);

    std::cout << "Postponement::fired() DONE" << std::endl;
}

} // namespace WebCore
