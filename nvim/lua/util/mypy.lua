local M = {}

-- Reads [tool.mypy] out of the project's pyproject.toml so pyright's
-- python_version/extraPaths can be derived from it instead of duplicated by
-- hand. Returns nil if there's no pyproject.toml or no [tool.mypy] section.
--
-- Deliberately does NOT read mypy's `exclude`: mypy excludes tests/dags/docs
-- from *type-checking*, but pyright's exclude means "don't analyze at all"
-- (no hover/go-to-def/references) - mirroring it broke find-references into
-- tests/. pyright already defaults to ignoring __pycache__/dotdirs on its own.
function M.parse_mypy_config(root_dir)
  local path = root_dir .. "/pyproject.toml"
  if vim.fn.filereadable(path) == 0 then
    return nil
  end

  local lines = vim.fn.readfile(path)
  local in_section = false
  local result = {}

  local i = 1
  while i <= #lines do
    local line = lines[i]

    if line:match("^%[tool%.mypy%]") then
      in_section = true
    elseif in_section and line:match("^%[") then
      break
    elseif in_section then
      local version = line:match('python_version%s*=%s*"([^"]+)"')
      if version then
        result.python_version = version
      end

      local mypy_path = line:match('mypy_path%s*=%s*"([^"]+)"')
      if mypy_path then
        result.mypy_path = vim.split(mypy_path, ":", { trimempty = true })
      end
    end

    i = i + 1
  end

  return next(result) and result or nil
end

return M
