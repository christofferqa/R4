/*
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

#include "DefaultScheduler.h"
#include "DOMTimer.h"
#include "EventActionRegister.h"
#include "ScheduledAction.h"
#include "ScriptExecutionContext.h"

namespace WebCore {

DefaultScheduler::DefaultScheduler()
    : m_stopped(false)
{
}

DefaultScheduler::~DefaultScheduler()
{
}

bool DefaultScheduler::isReplay()
{
    return false;
}

void DefaultScheduler::eventActionScheduled(const WTF::EventActionDescriptor& descriptor,
                                            EventActionRegister* eventActionRegister)
{
    if (!m_stopped) {
        eventActionRegister->runEventAction(descriptor);
    }
}

void DefaultScheduler::postponementScheduled(const WTF::EventActionDescriptor& descriptor,
                                            EventActionRegister* eventActionRegister)
{
}

void DefaultScheduler::eventActionDescheduled(const WTF::EventActionDescriptor&, EventActionRegister*)
{
}

void DefaultScheduler::executeDelayedEventActions(EventActionRegister*)
{
	// Do nothing.
}

void DefaultScheduler::stop()
{
    m_stopped = true;
}

}
