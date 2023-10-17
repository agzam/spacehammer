local M = {
  name="Spacehammer",
  version="3.0.0",
  author="Ag Ibragimov",
  license="MIT",
  homepage="https://github.com/agzam/spacehammer"
}

function M.init()
  dofile(hs.spoons.resourcePath("spacehammer"))
end

M
