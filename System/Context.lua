--===========================================================================--
--                                                                           --
--                              System.Context                               --
--                                                                           --
--===========================================================================--

--===========================================================================--
-- Author       :   kurapica125@outlook.com                                  --
-- URL          :   http://github.com/kurapica/PLoop                         --
-- Create Date  :   2020/08/18                                               --
-- Update Date  :   2020/08/27                                               --
-- Version      :   1.0.2                                                    --
--===========================================================================--

PLoop(function(_ENV)
    --- Represents the session to be used in the Context
    __Sealed__() class "System.Context.Session" (function(_ENV)

        -----------------------------------------------------------------------
        --                             property                              --
        -----------------------------------------------------------------------
        --- Gets or sets the session items
        __Indexer__()
        __Abstract__() property "Items"         {
            set = function(self, key, value)
                if self.RawItems[key]  ~= value then
                    self.ItemsChanged   = true
                    self.RawItems[key]  = value
                end
            end,
            get = function(self, key)
                return self.RawItems[key]
            end,
        }

        --- Gets the unique identifier for the session
        __Abstract__() property "SessionID"     { type = Any }

        --- The raw item table to be used for serialization
        __Abstract__() property "RawItems"      { default = function(self) self.IsNewSession = true return {} end }

        --- Gets or sets the date time, allowed the next request access the session
        __Set__ (PropertySet.Clone)
        __Abstract__() property "Timeout"       { type = Date, handler = function(self) self.TimeoutChanged = true end }

        --- Whether the time out is changed
        __Abstract__() property "TimeoutChanged"{ type = Boolean, default = false }

        --- Whether the current session is canceled
        __Abstract__() property "Canceled"      { type = Boolean, default = false }

        --- Gets a value indicating whether the session was newly created
        __Abstract__() property "IsNewSession"  { type = Boolean, default = false }

        --- Whether the session items has changed
        __Abstract__() property "ItemsChanged"  { type = Boolean, default = false }

        --- The context
        __Abstract__() property "Context"       { type = Context }

        -----------------------------------------------------------------------
        --                            constructor                            --
        -----------------------------------------------------------------------
        --- Get or generate the session for a http context
        __Arguments__{ System.Context/nil }
        function __ctor(self, context)
            self.Context        = context
        end
    end)

    --- Represents the session item storage provider
    __Sealed__() interface "System.Context.ISessionStorageProvider" (function(_ENV)

        -----------------------------------------------------------------------
        --                              method                               --
        -----------------------------------------------------------------------
        --- Process the context with session to save the items
        function SaveContextSession(self, context)
            local session       = context.RawSession
            if session then
                if session.Canceled then
                    return self:RemoveItems(session.SessionID)
                elseif session.IsNewSession or session.ItemsChanged then
                    return self:SetItems(session.SessionID, session.RawItems, session.Timeout)
                elseif session.TimeoutChanged then
                    return self:ResetItems(session.SessionID, session.Timeout)
                end
            end
        end

        --- Whether the session ID existed in the storage.
        __Abstract__() function Contains(self, id) end

        --- Get session item
        __Abstract__() function GetItems(self, id) end

        --- Remove session item
        __Abstract__() function RemoveItems(self, id) end

        --- Try sets the item with an un-existed key, return true if success
        __Abstract__() function TrySetItems(self, id, time, timeout) end

        --- Update the item with current session data
        __Abstract__() function SetItems(self, id, item, timeout) end

        --- Update the item's timeout
        __Abstract__() function ResetItems(self, id, timeout) end
    end)

    --- A test session storage provider based on the Lua table
    __Sealed__() class "System.Context.TableSessionStorageProvider" (function (_ENV)
        extend "System.Context.ISessionStorageProvider"

        export {
            ostime              = _G.os and os.time or _G.time,
            pairs               = pairs,
        }

        -----------------------------------------------------------------------
        --                          inherit method                           --
        -----------------------------------------------------------------------
        function Contains(self, id)
            return self.Storage[id] and true or false
        end

        function GetItems(self, id)
            local item          = self.Storage[id]
            if item then
                local timeout   = self.Timeout[id]
                if timeout and timeout.Time < ostime() then
                    self:RemoveItem(id)
                else
                    return item
                end
            end
        end

        function RemoveItems(self, id)
            self.Storage[id]    = nil
            self.Timeout[id]    = nil
        end

        function SetItems(self, id, item, timeout)
            self.Storage[id]    = item
            if timeout then
                self.Timeout[id]= timeout
            end
        end

        function ResetItems(self, id, timeout)
            if timeout and self.Storage[id] then
                self.Timeout[id]= timeout
            end
        end

        function TrySetItems(self, id, time, timeout)
            if self.Storage[id] ~= nil then return false end
            self:SetItems(id, time, timeout)
            return true
        end

        -----------------------------------------------------------------------
        --                             property                              --
        -----------------------------------------------------------------------
        property "Storage"  { type = Table, default = function() return {} end }
        property "Timeout"  { type = Table, default = function() return {} end }

        -----------------------------------------------------------------------
        --                              method                               --
        -----------------------------------------------------------------------
        function ClearTimeoutItems(self)
            local storage       = self.Storage
            local timeouts      = self.Timeout
            local now           = ostime()
            for id in pairs(storage) do
                if timeouts[id] and timeouts[id].Time < now then
                    storage[id] = nil
                    timeouts[id]= nil
                end
            end
        end
    end)
end)