local fs        = require "lemoon.fs"
local sys       = require "lemoon.sys"
local class     = require "lemoon.class"
local throw     = require "lemoon.throw"
local filepath  = require "lemoon.filepath"
local logger    = class.new("lemoon.log","gsmake")

local loadedpackages    = {}
local loadstack         = {}
local linkdependencies  = nil

linkdependencies = function(sync,dependencies)

    for _,dep in ipairs(dependencies) do

        if not dep.version then dep.version = defaultversion end

        if loadedpackages[dep.name] then
            if loadedpackages[dep.name].version ~= dep.version then
                print(string.format("conflict package(%s) version",dep.name))
                print("one :")
                for i,stack in ipairs(loadstack) do
                    print(string.format("%s%s->",string.rep(" ",i),stack.Name))
                end

                print("two :")
                for i,stack in ipairs(loadedpackages[dep.name].stack) do
                    print(string.format("%s%s->",string.rep(" ",i),stack.Name))
                end

                return true
            end
        end

        local path = sync:sync(dep.name,dep.version)

        local linked = filepath.join(gopath,"src",dep.name)

        if not fs.exists(filepath.dir(linked)) then
            fs.mkdir(filepath.dir(linked),true)
        end

        if fs.exists(linked) then
            fs.rm(linked)
        end

        local package = class.new("gsmake.loader",loader.GSMake,path,dep.name,dep.version).Package

        if not package.External then
            table.insert(loadstack,package)
            local properties  = package.Properties.golang or {}
            if linkdependencies(package.Loader.Sync,properties.dependencies or {}) then
                return true
            end
            table.remove(loadstack)
        end

        loadedpackages[dep.name] = { version = dep.version; stack = class.clone(loadstack); }

        fs.symlink(path,linked)
    end

end

task.resources = function(self)

    local ok, go_tools_path = sys.lookup("go")

    if not ok then
        print(string.format("golang tools not found,visit website:https://golang.org/dl/ for more information"))
        return true
    end

    go = go_tools_path

    properties        = self.Owner.Properties.golang or {}
    local sync        = self.Owner.Loader.Sync
    defaultversion    = self.Owner.Loader.Config.DefaultVersion

    local tmp = self.Owner.Loader.Temp

    gopath = filepath.join(tmp,"golang")

    if not fs.exists(gopath) then
        fs.mkdir(gopath,true)
    end

    table.insert(loadstack,self.Owner)

    if linkdependencies(sync,properties.dependencies or {}) then
        return true
    end

    linked = filepath.join(gopath,"src",self.Owner.Name)

    if not fs.exists(filepath.dir(linked)) then
        fs.mkdir(filepath.dir(linked),true)
    end

    if fs.exists(linked) then
        fs.rm(linked)
    end

    fs.symlink(self.Owner.Path,linked)

end
task.resources.Desc = "prepare dependencies package"

task.precompile = function(self)
end
task.precompile.Desc = "golang precompile task"
task.precompile.Prev = "resources"


task.compile = function(self)

    outputdir = filepath.join(gopath,"bin")
    sys.setenv("GOPATH",gopath)

    for _,binary in ipairs(properties.binaries or {}) do
        local exec = sys.exec(go)

        if type(binary) == "table" then
            local path = filepath.join(linked,binary.path)
            name = binary.name
            exec:dir(path)
            print(string.format("compile %s :\n",name))
            local ok,err = pcall(exec.start,exec,"build","-o",outputdir .. name .. sys.EXE_NAME)

            if not ok then
                print(string.format("compile target(%s) error\n\t%s",binary,err))
                return true
            end
        else
            local path = filepath.join(linked,binary)
            name = binary
            exec:dir(path)
            print(string.format("compile %s :\n",name))
            local ok,err = pcall(exec.start,exec,"install")

            if not ok then
                print(string.format("compile target(%s) error\n\t%s",binary,err))
                return true
            end
        end

        if 0 ~= exec:wait() then
            print(string.format("compile %s -- failed",name))
            return true
        end
    end
end

task.compile.Desc = "golang package compile task"
task.compile.Prev = "precompile"

task.gorun = function(self,name,...)

    local path = filepath.join(outputdir,name .. sys.EXE_NAME)

    local exec = sys.exec(path)
    exec:run(...)
end
task.gorun.Desc = "run package's binary"
task.gorun.Prev = "compile"

task.test = function(self,name,...)

    sys.setenv("GOPATH",gopath)

    local tests = properties.tests or {}

    if name ~= "" and name ~= nil then
        tests = { name }
    end


    for _,test in pairs( tests ) do
        local exec = sys.exec(go)
        exec:dir(filepath.join(linked,test))
        local ok,err = pcall(exec.start,exec,"test",...)

        if not ok then
            print(string.format("compile target(%s) error\n\t%s",binary,err))
            return true
        end

        if 0 ~= exec:wait() then
            print(string.format("run golang test(%s) -- failed",test))
            return true
        end
    end



end
task.test.Desc = "run golang test command"
task.test.Prev = "resources"

task.install = function(self,install_path)
    fs.copy_dir(outputdir,filepath.join(install_path,"bin"),fs.update_existing)
end
task.install.Desc = "golang package install package"
task.install.Prev = "compile"


task.gopath = function(self,name,...)
    sys.setenv("GOPATH",gopath)

    local ok, atom = sys.lookup(name)

    if ok then
        local exec = sys.exec(atom)
        exec:run(...)
    else
        print(name .. " not found")
    end
end
task.gopath.Desc = "start command with package's private GOPATH"
task.gopath.Prev = "resources"
