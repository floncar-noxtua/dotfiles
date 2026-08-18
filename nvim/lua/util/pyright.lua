local parse_mypy_config = require("util.mypy").parse_mypy_config

local M = {}

-- Finds a project-local venv (e.g. one created by `uv sync`) so pyright can
-- be pointed at it. Without this, pyright has no way to know which
-- interpreter's site-packages to resolve third-party imports against.
local function find_venv_python(root_dir)
  for _, dir in ipairs({ ".venv", "venv" }) do
    local python = root_dir .. "/" .. dir .. "/bin/python"
    if vim.fn.executable(python) == 1 then
      return python
    end
  end
  return nil
end

-- Runs once per project root right before pyright's initialize request is
-- sent, so we can inject settings computed from that root's pyproject.toml.
-- pcall guards against a missing/malformed file so it never blocks pyright
-- from starting.
function M.before_init(_, config)
  config.settings = config.settings or {}
  config.settings.python = config.settings.python or {}
  config.settings.python.analysis = config.settings.python.analysis or {}

  -- point pyright at the project's .venv/venv (e.g. from `uv sync`)
  -- so it resolves third-party imports, not just typeshed stubs
  local venv_python = find_venv_python(config.root_dir)
  if venv_python then
    config.settings.python.pythonPath = venv_python
  end

  local ok, mypy = pcall(parse_mypy_config, config.root_dir)
  if not ok or not mypy then
    return
  end

  -- python_version="3.12" -> pyright's python.pythonVersion
  if mypy.python_version then
    config.settings.python.pythonVersion = mypy.python_version
  end

  -- mypy_path="src" -> pyright's extraPaths, so it resolves
  -- first-party imports the same way mypy does
  if mypy.mypy_path then
    config.settings.python.analysis.extraPaths = mypy.mypy_path
  end
end

return M
