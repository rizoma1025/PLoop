
--===========================================================================--
--                                                                           --
--                       System.Reactive.ReactiveValue                       --
--                                                                           --
--===========================================================================--

--===========================================================================--
-- Author       :   kurapica125@outlook.com                                  --
-- URL          :   http://github.com/kurapica/PLoop                         --
-- Create Date  :   2024/05/22                                               --
-- Update Date  :   2024/05/22                                               --
-- Version      :   2.0.0                                                    --
--===========================================================================--

PLoop(function(_ENV)
    --- Represents the reactive value
    __Sealed__()
    __Arguments__{ AnyType/nil }
    class"System.Reactive.ReactiveValue"(function(_ENV, valtype)
        inherit "Subject"
        extend "IValueWrapper"

        export                          {
            subscribe                   = Subject.Subscribe,
            onnext                      = Subject.OnNext,
            onerror                     = Subject.OnError,
            geterrormessage             = Struct.GetErrorMessage,
        }

        -----------------------------------------------------------------------
        --                              method                               --
        -----------------------------------------------------------------------
        --- Subscribe the observer
        function Subscribe(self, ...)
            local subscription, observer= subscribe(self, ...)
            observer:OnNext(self[1])
            return subscription, observer
        end

        --- Provides the observer with new data
        if not valtype or Platform.TYPE_VALIDATION_DISABLED and getmetatable(valtype).IsImmutable(valtype) then
            function OnNext(self, val)
                self[1]                 = val
                return onnext(self, val)
            end
        else
            local valid                 = getmetatable(valtype).ValidateValue
            function OnNext(self, val)
                local ret, msg          = valid(valtype, val)
                if msg then return onerror(self, geterrormessage(msg, "value")) end
                self[1]                 = ret
                return onnext(self, ret)
            end
        end

        --- Sets observable as raw value
        __Arguments__{ IObservable }
        function SetRaw(self, observable)
            self.Observable             = observable
        end

        --- Sets the raw value
        __Arguments__{ (valtype or Any)/nil }
        function SetRaw(self, value)
            self.Observable             = nil
            self.Value                  = value
        end

        --- Gets the raw value
        function ToRaw(self)            return self[1] end

        -----------------------------------------------------------------------
        --                             property                              --
        -----------------------------------------------------------------------
        --- Whether always connect the observable
        property "KeepAlive"            { type = Boolean, default = true }

        --- The current value, use handler not set to detect the value change
        property "Value"                { type = valtype, field = 1, handler = "OnNext" }

        -----------------------------------------------------------------------
        --                            constructor                            --
        -----------------------------------------------------------------------
        -- Generate reactive value based on other observable
        __Arguments__{ IObservable }
        function __ctor(self, observable)
            super(self, observable)
        end

        -- Generate reactive value with init data
        __Arguments__{ (valtype or Any)/nil }
        function __ctor(self, val)
            super(self)
            self[1]                     = val
        end
    end)
end)