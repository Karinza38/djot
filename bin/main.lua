local djot = require("djot")

local help = [[
djot [opts] [file*]

Options:
-m        Show matches.
-a        Show AST.
-j        Use JSON for -m or -a.
-p        Include source positions in AST.
-v        Verbose (show warnings).
-h        Help.
]]

local function err(msg, code)
  io.stderr:write(msg .. "\n")
  os.exit(code)
end

local opts = {}
local files = {}

local argi = 1
while arg[argi] do
  local thisarg = arg[argi]
  if string.find(thisarg, "^%-") then
    string.gsub(thisarg, "(%a)", function(x)
      if x == "m" then
        opts.matches = true
      elseif x == "a" then
        opts.ast = true
      elseif x == "j" then
        opts.json = true
      elseif x == "p" then
        opts.sourcepos = true
      elseif x == "v" then
        opts.verbose = true
      elseif x == "f" then
        if arg[argi + 1] then
          opts.filters = opts.filters or {}
          table.insert(opts.filters, arg[argi + 1])
          argi = argi + 1
        end
      elseif x == "h" then
        io.stdout:write(help)
        os.exit(0)
      else
        err("Unknown option " .. x, 1)
      end
    end)
  else
    table.insert(files, thisarg)
  end
  argi = argi + 1
end

local inp
if #files == 0 then
  inp = io.read("*all")
else
  local buff = {}
  for _,f in ipairs(files) do
    local ok, msg = pcall(function() io.input(f) end)
    if ok then
      table.insert(buff, io.read("*all"))
    else
      err(msg, 7)
    end
  end
  inp = table.concat(buff, "\n")
end

local warn = function(warning)
  if opts.verbose then
    io.stderr:write(string.format("%s at byte position %d\n",
      warning.message, warning.pos))
  end
end

if opts.matches then

  djot.render_matches(inp, io.stdout, opts.json, warn)

else

  local doc = djot.parse(inp, opts.sourcepos, warn)

  if opts.filters then
    for _,fp in ipairs(opts.filters) do
      local oldpackagepath = package.path
      package.path = "?.lua;" .. package.path
      local filter = require(fp)
      package.path = oldpackagepath
      if #filter > 0 then -- multiple filters as in pandoc
        for _,f in ipairs(filter) do
          doc:apply_filter(f)
        end
      else
        doc:apply_filter(filter)
      end
    end
  end

  if opts.ast then
    doc:render_ast(io.stdout, opts.json)
  else
    doc:render_html(io.stdout, opts.json)
  end

end

os.exit(0)
