--===========================================================================--
--                                                                           --
--                              System.Reactive                              --
--                                                                           --
--===========================================================================--

--===========================================================================--
-- Author       :   kurapica125@outlook.com                                  --
-- URL          :   http://github.com/kurapica/PLoop                         --
-- Create Date  :   2023/04/20                                               --
-- Update Date  :   2024/04/01                                               --
-- Version      :   2.0.0                                                    --
--===========================================================================--

PLoop(function(_ENV)
    -----------------------------------------------------------------------
    --                            Declaration                            --
    -----------------------------------------------------------------------
    class "System.Reactive"                 {}
    class "System.Reactive__Observable__"   {}
    class "System.Reactive.BehaviorSubject" {}
    class "System.Reactive.ReactiveList"    {}

    -----------------------------------------------------------------------
    --                          Implementation                           --
    -----------------------------------------------------------------------
    --- The proxy used to access reactive table field datas
    __Sealed__()
    __Arguments__{ -IKeyValueDict/nil, AnyType/nil, AnyType/nil }
    __NoNilValue__(false):AsInheritable()
    __NoRawSet__(false):AsInheritable()
    class "System.Reactive"             (function(_ENV, targetclass, keytype, valtype)
        extend "IObservable" "IKeyValueDict"

        export                          {
            type                        = type,
            pairs                       = pairs,
            error                       = error,
            tostring                    = tostring,
            rawget                      = rawget,
            rawset                      = rawset,
            next                        = next,
            pcall                       = pcall,
            yield                       = coroutine.yield,
            getmetatable                = getmetatable,
            isObjectType                = Class.IsObjectType,
            getEventDelegate            = Event.Get,

            -- bind data change event handler when accessed
            bindDataChange              = function(self, k, r)
                if r and getEventDelegate(OnDataChange, self, true) and (isObjectType(r, Reactive) or isObjectType(r, ReactiveList)) then
                    r.OnDataChange      = r.OnDataChange + function(_, ...) return OnDataChange(self, k, ...) end
                end
                return r
            end,

            -- handle data change event
            handleDataChangeEvent       = function(_, owner, name, init)
                if not init then return end
                local reactives         = owner[Reactive]
                for k, r in pairs(reactives) do
                    bindDataChange(owner, k, r)
                end
            end,

            -- wrap the table value as default
            makeReactive                = function(self, k, v)
                local r                 = reactive(v, true)
                self[Reactive][k]       = r or false
                return r and bindDataChange(self, k, r)
            end,

            Class, Property, Event, Reactive, ReactiveList, BehaviorSubject, Observable
        }

        -------------------------------------------------------------------
        --                             event                             --
        -------------------------------------------------------------------
        --- Fired when the data changed
        __EventChangeHandler__(handleDataChangeEvent)
        event "OnDataChange"

        -------------------------------------------------------------------
        --                         common method                         --
        -------------------------------------------------------------------
        --- Subscribe the observers
        function Subscribe(self, ...)   return Observable.From(self.OnDataChange):Subscribe(...) end

        --- Map the items to other type datas, use collection operation instead of observable
        Map                             = IKeyValueDict.Map

        --- Used to filter the items with a check function
        Filter                          = IKeyValueDict.Filter

        -- For dictionaryd
        if targetclass and Class.IsSubType(targetclass, IKeyValueDict) then
            export                      {
                toRaw                   = Reactive.ToRaw,
                setRaw                  = function(self, k, v) self[k] = v end,
                objMap                  = not Platform.MULTI_OS_THREAD and Toolset.newtable(true, true) or false,
            }

            ---------------------------------------------------------------
            --                          method                           --
            ---------------------------------------------------------------
            --- Gets the iterator
            __Iterator__()
            function GetIterator(self)
                local yield             = yield
                for k, v in self[Class]:GetIterator() do
                    if type(k) == "string" then
                        yield(k, self[k])
                    elseif k ~= Reactive then
                        yield(k, v)
                    end
                end
            end

            ---------------------------------------------------------------
            --                        constructor                        --
            ---------------------------------------------------------------
            --- bind the reactive and object
            __Arguments__{ IKeyValueDict }
            function __ctor(self, init)
                rawset(self, Reactive, {})
                rawset(self, Class,  init)

                -- avoid to set value in raw dict object if possible
                if objMap then
                    objMap[init]        = self
                else
                    rawset(init, Reactive, self)
                end
            end

            --- use the wrap for objects
            function __exist(_, init)
                if objMap then return objMap[init] end
                return isObjectType(init, Reactive) and init or rawget(init, Reactive)
            end

            ---------------------------------------------------------------
            --                        meta-method                        --
            ---------------------------------------------------------------
            --- Gets the current value
            function __index(self, key)
                -- get existed reactive
                local reactives         = rawget(self, Reactive)
                local r                 = reactives[key]
                if r then return r end

                -- wrap raw
                local value             = rawget(self, Class)[key]
                return r == nil and value ~= nil and type(key) == "string" and makeReactive(self, key, value) or value
            end

            --- Send the new value
            if (keytype and keytype ~= Any) or (valtype and valtype ~= Any) then
                __Arguments__{ keytype or Any, valtype or Any }
            end
            function __newindex(self, key, value)
                if type(value) == "table" then
                    value               = toRaw(value)
                end

                -- check raw
                local raw               = self[Class]
                if raw[key] == value then return end

                -- check reactive
                local reactives         = self[Reactive]
                local r                 = reactives[key]
                if r then
                    -- BehaviorSubject
                    if isObjectType(r, BehaviorSubject) then
                        raw[key]        = value
                        r:OnNext(value)
                        return OnDataChange(self, key, value)

                    -- only accept raw table value
                    elseif type(value) == "table" and getmetatable(value) == nil then
                        SetRaw(r, value, 2)
                        return

                    -- not valid
                    else
                        error("The reactive field " .. tostring(key) .. " is a reactive table, only accept table value", 2)
                    end
                elseif r == false then
                    reactives[key]      = nil
                end

                -- raw directly
                local ok, err           = pcall(setRaw, raw, key, value)
                if not ok then error(err, 2) end

                -- make table reactive now, since it may be used in the event handler
                return OnDataChange(self, key, type(key) == "string" and type(value) == "table" and makeReactive(self, key, value) or value)
            end

        -- As container for reactive fields, common usages
        else
            export                      {
                pcall                   = pcall,
                pairs                   = pairs,
                getmetatable            = getmetatable,
                isSubType               = Class.IsSubType,
                getFeatures             = Class.GetFeatures,
                isProperty              = Property.Validate,
                isWritable              = Property.IsWritable,
                isIndexer               = Property.IsIndexer,
                rawMap                  = not Platform.MULTI_OS_THREAD and Toolset.newtable(true, true) or false,

                updateTable             = function(self, value)
                    local raw           = rawget(self, Class) or rawget(self, RawTable)
                    if not raw then return end

                    -- update
                    local temp          = {}
                    for k in self:GetIterator() do
                        temp[k]         = true
                        self[k]         = value[k]
                    end

                    -- add
                    for name in pairs(value) do
                        if not temp[name] then
                            self[name]  = value[name]
                        end
                    end

                    -- release
                    temp                = nil
                end,

                Reactive, ReactiveList, BehaviorSubject, RawTable
            }

            ---------------------------------------------------------------
            --                       static method                       --
            ---------------------------------------------------------------
            --- Gets the current raw value of the reactive object
            __Static__()
            function ToRaw(self)
                -- for values
                if type(self) ~= "table" then return self end

                -- for raw table
                local cls               = getmetatable(self)
                if cls == nil then return self end

                -- behavior subject
                if isSubType(cls, BehaviorSubject) then
                    return self.Value

                -- reactive list
                elseif isSubType(cls, ReactiveList) then
                    return ReactiveList.ToRaw(self)

                -- reactive
                elseif isSubType(cls, Reactive) then
                    return rawget(self, Class) or rawget(self, RawTable)
                end

                -- other
                return self
            end

            --- Sets a raw table value to the reactive object
            __Static__()
            function SetRaw(self, value, stack)
                local cls               = getmetatable(self)
                if type(self) ~= "table" or not cls then error("Usage: Reactive.SetRaw(reactive, value[, stack]) - the reactive not valid", (stack or 1) + 1) end

                -- behavior subject
                if isSubType(cls, BehaviorSubject) then
                    return self:OnNext(value)

                -- reactive list
                elseif isSubType(cls, ReactiveList) then
                    ReactiveList.SetRaw(self, value, (stack or 1) + 1)
                    return

                -- reactive
                elseif isSubType(cls, Reactive) then
                    if value ~= nil and type(value) ~= "table" then
                        error("Usage: Reactive.SetRaw(reactive, value[, stack]) - the value not valid", (stack or 1) + 1)
                    end

                    -- as object proxy
                    local ok, err       = pcall(updateTable, self, value)
                    if not ok then error("Usage: Reactive.SetRaw(reactive, value) - " .. err, (stack or 1) + 1) end
                    return
                end

                -- other
                error("Usage: Reactive.SetRaw(reactive, value[, stack]) - the reactive not valid", (stack or 1) + 1)
            end

            ---------------------------------------------------------------
            --                          method                           --
            ---------------------------------------------------------------
            --- Gets the iterator
            __Iterator__()
            function GetIterator(self)
                local yield             = yield
                for k, v in pairs(self[RawTable]) do
                    if type(k) == "string" then
                        yield(k, self[k])
                    elseif k ~= Reactive then
                        yield(k, v)
                    end
                end
            end

            ---------------------------------------------------------------
            --                        constructor                        --
            ---------------------------------------------------------------
            __Arguments__{ RawTable/nil }
            function __ctor(self, init)
                rawset(self, Reactive, {})
                rawset(self, RawTable, init or {})

                if init then
                    -- record the map
                    if rawMap then
                        rawMap[init]    = self
                    else
                        rawset(init, Reactive, self)
                    end
                end
            end

            __Arguments__{ RawTable/nil }
            function __exist(_, init)
                if not init then return end
                return rawMap and rawMap[init] or rawget(init, Reactive)
            end

            ---------------------------------------------------------------
            --                        meta-method                        --
            ---------------------------------------------------------------
            --- Gets the current value
            function __index(self, key)
                local reactives         = rawget(self, Reactive)
                local r                 = reactives[key]
                if r then return r end

                -- wrap raw
                local value             = rawget(self, RawTable)[key]
                return r == nil and value ~= nil and type(key) == "string" and makeReactive(self, key, value) or value
            end

            --- Send the new value
            function __newindex(self, key, value)
                -- unpack
                if type(value) == "table" then
                    value               = toRaw(value)
                end

                -- check raw
                local raw               = self[RawTable]
                if raw[key] == value    then return end

                -- check the reactive
                local reactives         = rawget(self, Reactive)
                local r                 = reactives[key]
                if r then
                    -- BehaviorSubject
                    if isObjectType(r, BehaviorSubject) then
                        -- update
                        raw[key]        = value
                        r:OnNext(value)
                        return OnDataChange(self, key, value)

                    -- only accept raw table value
                    elseif type(value) == "table" and getmetatable(value) == nil then
                        SetRaw(r, value, 2)
                        return

                    -- not valid
                    else
                        error("The reactive field " .. tostring(key) .. " is a reactive table, only accept table value", 2)
                    end
                elseif r == false then
                    reactives[key]      = nil
                end

                -- raw directly
                raw[key]                = value

                -- make table reactive now, since it may be used in the event handler
                return OnDataChange(self, key, type(key) == "string" and type(value) == "table" and makeReactive(self, key, value) or value)
            end

            export { toRaw = ToRaw }
        end
    end)

    -----------------------------------------------------------------------
    --                              Keyword                              --
    -----------------------------------------------------------------------
    Environment.RegisterGlobalNamespace("System.Reactive")

    export                              {
        type                            = type,
        pcall                           = pcall,
        error                           = error,
        tostring                        = tostring,
        getmetatable                    = getmetatable,
        getObjectClass                  = Class.GetObjectClass,
        isSubType                       = Class.IsSubType,
        isObjectType                    = Class.IsObjectType,
        isarray                         = Toolset.isarray,
        isValueType                     = Class.IsValueType,
        getTemplateParameters           = Class.GetTemplateParameters,

        IObservable, Reactive, ReactiveList, BehaviorSubject, Any,
        IList, List, IDictionary, Dictionary, Proxy, IIndexedList, IKeyValueDict
    }

    --- Whether the value can be wrap to a reactive object
    __Static__() function Reactive.IsReactable(value, onlyContainer)
        -- Check the value
        local tval                      = type(value)
        if tval == "table" then
            -- Check the class
            local cls                   = getObjectClass(value)

            if cls then
                -- already reactable
                if isSubType(cls, Reactive) or isSubType(cls, ReactiveList) then
                    return true

                elseif isSubType(cls, BehaviorSubject) or isSubType(cls, IObservable) or isValueType(cls) then
                    return not onlyContainer

                -- wrap list or array to reactive list
                elseif isSubType(cls, IList) then
                    return isSubType(cls, List)

                -- wrap dictionary
                elseif isSubType(cls, IDictionary) then
                    return isSubType(cls, IKeyValueDict)
                end

                -- not allow common object
                return false
            end

            -- raw table/array always be reactable
            return true

        elseif tval == "number" or tval == "string" or tval == "boolean" then
            return not onlyContainer
        end

        return false
    end

    Environment.RegisterRuntimeKeyword  {
        --- Wrap the target value to a Reactive(for table or object), ReactiveList(for list) or BehaviorSubjcet(for value)
        reactive                        = function(value, silent)
            if value == nil then        return Reactive() end

            -- Check the value
            local tval                  = type(value)
            if tval == "table" then
                local cls               = getObjectClass(value)

                if cls then
                    -- already wrap
                    if isSubType(cls, Reactive) or isSubType(cls, ReactiveList) or isSubType(cls, BehaviorSubject) then
                        return value

                    -- wrap the observable or value as behavior subject
                    elseif isSubType(cls, IObservable) or isValueType(cls) then
                        return BehaviorSubject(value)

                    -- wrap list or array to reactive list
                    elseif isSubType(cls, IList) then
                        -- To complex to cover more list types, only List for now
                        if isSubType(cls, List) then
                            local etype = getTemplateParameters(cls)
                            return ReactiveList[etype or Any](value)

                        elseif not silent then
                            error("Usage: reactive(data[, silent]) - the data of " .. tostring(cls) .. " is not supported", 2)
                        end
                        return

                    -- wrap dictionary
                    elseif isSubType(cls, IDictionary) then
                        if isSubType(cls, Dictionary) or isSubType(cls, Proxy) then
                            -- can get the key/value types
                            local k, v  = getTemplateParameters(cls)
                            if k == Any then k = nil end
                            if v == Any then k = nil end
                            return Reactive[{ Dictionary, k, v }](value)

                        elseif isSubType(cls, IKeyValueDict) then
                            -- can't get the key/value types
                            return Reactive[Dictionary](value)

                        elseif not silent then
                            error("Usage: reactive(data[, silent]) - the data of " .. tostring(cls) .. " is not supported", 2)
                        end
                        return

                    -- don't support other types
                    else
                        error("Usage: reactive(data[, silent]) - the data of " .. tostring(cls) .. " is not supported", 2)
                    end
                end

                -- wrap array to reactive list
                if isarray(value) then
                    return ReactiveList(value)

                -- wrap the table to Reactive
                else
                    return Reactive(value)
                end

            -- wrap scalar value to behavior subject
            elseif tval == "number" or tval == "string" or tval == "boolean" then
                return BehaviorSubject(value)

            -- wrap function to a behavior subject that subscribe an observable generated from the function
            elseif tval == "function" then
                return BehaviorSubject(Observable(value))
            end

            -- throw error if not silent
            if not silent then
                error("Usage: reactive(data[, silent]) - the data can't be converted to a reactive object", 2)
            end
        end
    }
end)