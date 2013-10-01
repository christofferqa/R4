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
 */

#ifndef EventActionSchedule_h
#define EventActionSchedule_h

#include <string>
#include <ostream>
#include <istream>

#include <wtf/Noncopyable.h>
#include <wtf/ExportMacros.h>
#include <wtf/Vector.h>

#include "EventActionDescriptor.h"

namespace WebCore {

    class EventActionSchedule {
        WTF_MAKE_NONCOPYABLE(EventActionSchedule);

    public:
        EventActionSchedule();
        EventActionSchedule(const WTF::Vector<EventActionDescriptor>&);
        ~EventActionSchedule();

        EventActionDescriptor allocateEventDescriptor(const std::string& description);

        void serialize(std::ostream& stream) const;
        static EventActionSchedule* deserialize(std::istream& stream);

        void eventActionDispatchStart(const EventActionDescriptor& descriptor)
        {
            ASSERT(!m_isDispatching);

            m_schedule.append(descriptor);
            m_isDispatching = true;
        }

        void eventActionDispatchEnd()
        {
            ASSERT(m_isDispatching);

            m_isDispatching = false;
        }

        const EventActionDescriptor& currentEventActionDispatching() const
        {
            if (m_isDispatching) {
                return m_schedule.isEmpty() ? EventActionDescriptor::null : m_schedule.last();
            }

            return EventActionDescriptor::null;
        }

        WTF::Vector<EventActionDescriptor> getVectorCopy() const
        {
            return m_schedule;
        }

    private:

        WTF::Vector<EventActionDescriptor> m_schedule;
        unsigned long m_nextEventActionDescriptorId;

        bool m_isDispatching;
    };

}

#endif
