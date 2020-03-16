-- ------------------------------------------------------------------------------------------------------------------------------
-- Lua Make - a luajit based build too compatible with make schema
--
-- Built using makefile spec here:
-- https://pubs.opengroup.org/onlinepubs/009695399/utilities/make.html

local ffi = require( 'ffi' )

-- Cache commonly used lib commands
tremove = table.remove
tinsert = table.insert

-- ------------------------------------------------------------------------------------------------------------------------------
-- Defines
--
-- If windows cache current path and username
local PWD = ''
local OS = ''
local CC = 'tcc'

-- Can support 4 spaces instead of \t or tabs for commands
local TAB_SPACES = '    '

-- ------------------------------------------------------------------------------------------------------------------------------
-- On linux use gcc (will eventually use tcc though)
if ffi.os == 'Linux' then CC = 'gcc' end

function runcommand(cmd) 
    local f = assert(io.popen(cmd, 'r'))
    print(" ", cmd)
    local out = assert(f:read('*a'))
    f:close()
    return out                
end    


if ffi.os == "Windows" then 
PWD = string.sub(runcommand("cd"), 3, -1)
OS = ffi.os
end

-- ------------------------------------------------------------------------------------------------------------------------------
-- Allows string indexing - handy
getmetatable('').__index = function(str,i) return string.sub(str,i,i) end

-- remove trailing and leading whitespace from string.
-- http://en.wikipedia.org/wiki/Trim_(programming)
function trim(s)
    -- from PiL2 20.4
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

-- ------------------------------------------------------------------------------------------------------------------------------
-- Definitions

local MF_FOUND_MAKEFILE     = 1
local MF_CHECK_TARGETS      = 2

-- ------------------------------------------------------------------------------------------------------------------------------
-- By default, the following files shall be tried in sequence: ./makefile and ./Makefile. 
local mfileseq = { "./makefile", "./Makefile" }

local makelines = {}

-- ------------------------------------------------------------------------------------------------------------------------------
-- Internal data sets
local intermediates = {}    -- collection of files in folder, that are cleaned up at the end.
local targets = {}
local targetfiles = {}      -- List of src and dst files associated with a target (from inference rules)

local dependencies = {}     -- dependencies for a target
local comments = {}         -- Comments mapped to their line
local vars = {              -- all variables are collected here

    CC = CC
}

local processedlines = {}
local commands = {}         -- Commands are allocated to a target (usually)
local commandsordered = {}  -- A index list of the commands in order of file lines

local inferencerules = {}   -- Rules that apply to out-of-date files like:  .c.o   c source -> object files
-- The -f option shall direct make to ignore any of these default files and use the specified 
--    argument as a makefile instead. If the '-' argument is specified, standard input shall be used.

-- ------------------------------------------------------------------------------------------------------------------------------
-- Target rules definition
--    target [target...]: [prerequisite...][;command]
--    [<tab>command
--    <tab>command
--    ...]
-- line that does not begin with <tab>

-- ------------------------------------------------------------------------------------------------------------------------------
-- Inference rules are formatted as follows:
--    target:
--    <tab>command
--    [<tab>command]...
-- line that does not begin with <tab> or #

-- ------------------------------------------------------------------------------------------------------------------------------
-- Macro definitions are in the form:
--    string1 = [string2]

-- When an escaped <newline> (one preceded by a backslash) is found anywhere in the makefile 
--    except in a command line, it shall be replaced, along with any leading white space on the 
--    following line, with a single <space>. When an escaped <newline> is found in a command 
--    line in a makefile, the command line shall contain the backslash, the <newline>, and the 
--    next line, except that the first character of the next line shall not be included if it 
--    is a <tab>.

--  Macro expansions using the forms $( string1) or ${ string1} shall be replaced by string2

-- ------------------------------------------------------------------------------------------------------------------------------
-- Reserved Makefile variables
-- $(AR) $(BISON) $(CC) $(FLEX) $(INSTALL) $(LD) $(LDCONFIG) $(LEX)
-- $(MAKE) $(MAKEINFO) $(RANLIB) $(TEXI2DVI) $(YACC)

-- ------------------------------------------------------------------------------------------------------------------------------
function getallfiles( ext )

    local allfiles = ""
    local result = {}
    if ffi.os == "Windows" then 

        allfiles = runcommand( "dir *"..ext.." /b" )
    end 

    if ffi.os == "Linux" then 

        allfiles = runcommand( "ls -1 *"..ext )
    end

    -- Split lines from one string
    for line in string.gmatch(allfiles, "[^\r\n]+") do
        tinsert(result, line)
    end 
    return result
end

-- ------------------------------------------------------------------------------------------------------------------------------
-- Try loading in the provided makefile - check info.result for validity.
function tryloadingmakefile( filename, info )

    local file = io.open (filename)
    if file == nil then 
        print("[Makefile] Error cannot find file: ", filename)
        info.result = nil
    else 
        info.result = MF_FOUND_MAKEFILE
        for line in file:lines() do
            -- print( line )
            tinsert( makelines, line )
        end 
    end 
end

-- ------------------------------------------------------------------------------------------------------------------------------
-- Just collect lines in a table to manage.
function loadmake( info )

    -- if a makefile is provided with -f then try it and ignore defaults.
    if info.makefile then 

        tryloadingmakefile(info.makefile, info)
        if info.result == nil then os.exit() end
    end
    
    local mfindex = 1
    while mfindex <= #mfileseq and info.result == nil do 

        local filename = mfileseq[mfindex]
        tryloadingmakefile( filename, info )
        mfindex = mfindex + 1
    end 
end

-- ------------------------------------------------------------------------------------------------------------------------------

function parseparams( params )

    local info = {}
    local psize = #params
    local i = 1
    repeat

        local entry = params[i]
        -- print(i,entry)

        -- Check incoming params.
        if entry == "-f" then 

            i = i + 1
            if i<=psize then
             
                info.makefile = params[i]
            end

        -- Collect targets
        else 
            tinsert(targets, entry)
        end

        i = i + 1
    until i > psize

    return info
end

-- ------------------------------------------------------------------------------------------------------------------------------

function defaultcompile( source, dest )
    local cmd = vars.CC.." "..source.." -o "..dest
    print( runcommand( cmd ) )
end 

-- ------------------------------------------------------------------------------------------------------------------------------

function getmakefile( params )
    
    local info = parseparams( params )
    
    loadmake( info )
    if info.result == nil then 
        
        info.result = MF_CHECK_TARGETS 
        -- Check for default target processing
        for k,v in pairs(targets) do
            defaultcompile( v..".c", v..".o" )
        end
    end    

    return info
end
-- ------------------------------------------------------------------------------------------------------------------------------

function getcomments( k, str )

    local newvalue, cmt = string.match(str, "(.*)(#.*)")
    if newvalue then str = newvalue; comments[k] = cmt end
    return str
end

-- ------------------------------------------------------------------------------------------------------------------------------

function getspecialmacros( k, str )

    local result = str

    result = string.gsub( str, "%$%(MAKE%)", "luajit "..arg[0] )
    return result
end

-- ------------------------------------------------------------------------------------------------------------------------------

function replacemacros( da, str )

    if str == nil then return str end 

    local result = str
    
    for var in string.gmatch( result, "%$@") do
        result = string.gsub( result, "%$@", da.base..da.dst )
    end

    for var in string.gmatch( result, "%$%%") do
        result = string.gsub( result, "%$%%", da.base..da.src )
    end

    for var in string.gmatch( result, "%$%?") do

    end

    for var in string.gmatch( result, "%$<") do
        result = string.gsub( result, "%$<", da.base..da.src )
    end

    for var in string.gmatch( result, "%$%*") do
        result = string.gsub( result, "%$%*", da.base..da.dst )
    end

    return result
end

-- ------------------------------------------------------------------------------------------------------------------------------

function getexpansions( k, str )

    -- Expansion macros
    for var in string.gmatch( str, "%$%([%w%s_]+%)") do

        local exp = string.sub(var, 3, -2)

        -- try looking up in vars first
        if vars[exp] then repl = vars[exp] end

        -- shell command?
        if string.sub(exp, 1, 5) == 'shell' then 

            local cmd = string.sub(exp, 7, -1 )
            if DEBUG_COMMANDS_SHELL then print("[Shell Command] ",cmd) end

            if ffi.os == "Windows" then 
                local cmdrun = nil
                if string.sub(cmd, 1, 5) == "uname" then 
                    repl = OS
                    cmdrun = "uname"
                end
                if string.sub(cmd, 1, 3) == "pwd" then 
                    -- Need to remove the \n from the end of the string
                    repl = string.sub(PWD, 1, -2)
                    cmdrun = "pwd"
                end

                -- Try running any other command 
                if cmdrun == nil and cmd then 
                    repl = runcommand(cmd)
                end
            end
            if ffi.os == "Linux" then 
                -- On Linus just run the command and get the results - remove \n as well
                repl = string.sub(runcommand(cmd), 1, -2)
            end
        end

        str = string.gsub( str, "%$%("..exp.."%)", repl)
        if DEBUG_COMMANDS_EXPANSIONS then print("+++",exp, repl, str) end
    end
    return str
end

-- ------------------------------------------------------------------------------------------------------------------------------

function processvars(k, v)

    local res = getspecialmacros(k, v)
    res = getexpansions(k, res)

    -- easy one first - check variable (no : or . - must have = )
    local st, en, string1, string2 = string.find( res, "(.*)=(.*)" )
    if st and en then 

        -- Strip comments first
        string2 = getcomments(k, string2)

        --print(st, en, cap1, cap2)
        local key = string.gsub(string1, "%s+", "")
        local value = string2

        -- Check for plus equals (will have a plus (+) on the key)
        if(key[-1] == '+') then 
            key = string.sub(key, 1, -2)
            assert( vars[key] ~= nil, "\n[Makefile] Line: "..k.." Error: Variable not defined: "..key )
            value = vars[key].." "..value
        end

        -- Before setting value make sure any 
        vars[key] = value
        res = key.."="..value
    end

    return res
end

-- ------------------------------------------------------------------------------------------------------------------------------
local adding_command = nil

function checkinferencerules(target)

    local src, dst = string.match(target, "(%..*)(%..*)")

    if src and dst then 
        if string.len(src) < 10 and string.len(dst) < 10 then 
            -- print("Source:", src, "  Dest:", dst)
            -- get source files 
            local allfiles = getallfiles(src)
            local tfiles = {}
            for k,v in ipairs(allfiles) do 
                local basename = string.sub(v, 1, -(#src+1))
                tfiles[k] = { base=basename, src=src, dst=dst }
            end

            if #tfiles > 0 then targetfiles[target] = tfiles end
        end
    end
end

function checkrules(target)
    
    checkinferencerules(target)
end

function processrules(k, v)

    if adding_command then 
        -- If line begins with tab or #.. keep adding commands - we support 4 spaces too.
        if v[1] == '\t' or v[1] == '#' or ( string.match(v, '^'..TAB_SPACES) )then
            commands[adding_command] = commands[adding_command]..v..'\n' 
        else 
            adding_command = nil
        end
    else
        -- Find targets, then add commands to them
        local target, cmd = string.match(v, "(.*):(.*)")
        if target then 

            local res = checkrules(target)

            adding_command = target 
            tinsert(commandsordered, adding_command)
            commands[target] = ""
        end

        -- Check a command inline with target
        if cmd then 
            local cmdline = trim(cmd)
            if #cmdline > 0 then 
                dependencies[target] = cmdline
            end
        end
    end
    -- print(k, v)
end

-- ------------------------------------------------------------------------------------------------------------------------------

function runcommandsontarget( cmdstr )

    for line in string.gmatch(cmdstr, "[^\r\n]+") do
                
        local cmdline = trim(line)                  
        -- check first, that this isnt a target trying to be 'run'
        -- print("-----> Running command:\n", cmdline)  
        runcommand( cmdline ) 
    end
end

-- ------------------------------------------------------------------------------------------------------------------------------

function runcommandline( k, v )

    -- lookup in commands
    if commands[v] then 

        -- Check dependencies - tag if they have run. 
        --   TODO: check cyclic deps
        local dep = dependencies[v]
        if dep then 
            for element in string.gmatch( dep , "([%w%p]+)" ) do
                if  string.len(element) > 0 then 
                    if commands[element] then 
                        -- print("+++++> ", element)
                        runcommandline( k, element )
                    end
                end
            end
        end

        -- If there are target files then apply inference rules instead.
        local files = targetfiles[v]
        if files and #files > 0 then 

            for kk, vv in pairs(files) do 
                local repl = replacemacros( vv, commands[v] )
                print("----->", repl, vv.base)
                if repl then runcommandsontarget( repl ) end
            end
        else

            runcommandsontarget( commands[v] )
        end 

    end
end

-- ------------------------------------------------------------------------------------------------------------------------------
function checktargets() 

    local result = nil
    if #targets > 0 then 
        
        for k,v in ipairs(targets) do   
            
            runcommandline( k, v )
        end
    else 
        result = 1
    end    
    
    return result
end

-- ------------------------------------------------------------------------------------------------------------------------------
function runcommandlist() 

    if #commandsordered > 0 then 

        for k,v in ipairs(commandsordered) do

            runcommandline( k, v )
        end
    end
end

-- ------------------------------------------------------------------------------------------------------------------------------
local DEBUG_DUMP_VARS = nil
local DEBUG_DUMP_COMMANDS = nil
local DEBUG_DUMP_COMMANDLIST = nil

-- ------------------------------------------------------------------------------------------------------------------------------

function processlines()
   
    for k,v in ipairs( makelines ) do

        local newline = processvars(k, v)
        tinsert(processedlines, newline)
    end

    for k,v in ipairs( processedlines ) do

        processrules(k, v)
    end

    if DEBUG_DUMP_VARS then 

        for k,v in pairs(vars) do print(k, v) end 
    end 

    if DEBUG_DUMP_COMMANDS then 

        for k,v in pairs(commands) do print(k, v) end 
    end
    
    if DEBUG_DUMP_COMMANDLIST then 

        for k,v in ipairs(commandsordered) do print(k, v) end 
    end

    -- Check any targets if they were specified (and run their commands)
    if checktargets() then 
        runcommandlist() 
    end
end

-- ------------------------------------------------------------------------------------------------------------------------------

local info = getmakefile(arg)
if info.result == MF_FOUND_MAKEFILE then processlines() end

-- ------------------------------------------------------------------------------------------------------------------------------
