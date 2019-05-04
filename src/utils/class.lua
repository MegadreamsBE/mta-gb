Class = {}
Class = setmetatable(Class,Class)

--//Creates a class
function Class:__call(parent)
    -- Define class as an empty table
    local instance = {}

    -- Create storage where all methods & variables exist, also enables inheritance
    local storage = setmetatable({},{__index = parent or self})

    -- This list contains the objects created for that class (only created on the highest class of hierarchy)
    if not parent then
        storage.__instances = {}
    end

    -- Define behaviour for this new class pointing to storage & adding the ability to create instances of it
    local behaviour = {}
            behaviour.__index = storage
            behaviour.__newindex = storage
            behaviour.__call = function(_,...)
                return instance:create(...)
            end

    -- Update instance metatable using behaviour
    setmetatable(instance,behaviour)

    return instance
end

--//Creates an object
function Class:create(...)
    -- Limit method to classes only
    if self:isObject() then
        error("This method should be used on classes only")
    end

    -- Define object as an empty table linked to class itself (index goes to class)
    local instance = setmetatable({},{__index = self})

    -- Call constructor(s)
    instance:recursiveCall("constructor",...)

    -- Remove constructor access
    instance.constructor = false

    -- Add to instances list
    table.insert(self.__instances,instance)

    return instance
end

--//Destroys an object
function Class:destroy()
    -- Limit method to objects only
    if not self:isObject() then
        error("This method should be used on objects only")
    end

    -- Call destructor(s)
    self:recursiveCall("destructor")

    -- Remove destructor access
    self.destructor = false

    -- Remove from instances list
    for index,instance in pairs(self.__instances) do
        if instance == self then
            table.remove(self.__instances,index)
            break
        end
    end

    -- Detach metatable from this object
    setmetatable(self,nil)

    return true
end

--//Lets an object call a method across whole class tree.
function Class:recursiveCall(method,...)
    -- Limit method to objects only
    if not self:isObject() then
        error("This method should be used on objects only")
    end

    -- Get the class where this object belongs to
    local initialClass = self:getIndex()

    -- Generate class tree
    local classTree = {}
    local classInsert = initialClass

    while classInsert do
        -- Add to list
        table.insert(classTree,1,classInsert)

        -- Get the parent class for current insert
        classInsert = classInsert:getParent()
    end

    -- Look on each class for the method & call it
    for _,class in pairs(classTree) do
        local storage = class:getIndex()
        if storage then
            local funct = rawget(storage,method)
            if funct and type(funct) == "function" then
                funct(self,...)
            end
        end
    end
end

--//Get the parent class of some class
function Class:getParent()
    -- Limit method to classes only
    if self:isObject() then
        error("This method should be used on classes only")
    end

    -- Look for parent
    local storage = self:getIndex()
    if storage then
        local parent = storage:getIndex()
        if parent then
            return parent
        end
    end

    return false
end

--//Get the index for self
function Class:getIndex()
    local behaviour = getmetatable(self)
    if behaviour then
        local index = behaviour.__index
        if index then
            return index
        end
    end

    return false
end

--//Defines if self is an object
function Class:isObject()
    local behaviour = getmetatable(self)
    if behaviour then
        if not behaviour.__call then
            return true
        end
    end

    return false
end

--//Gets all the instances of a given class
function Class:getInstances()
    -- Limit method to classes only
    if self:isObject() then
        error("This method should be used on classes only")
    end

    return self.__instances
end
