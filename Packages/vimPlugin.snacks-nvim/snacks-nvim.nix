{
  vimUtils,
  fetchFromGitHub,
} :

vimUtils.buildVimPlugin {
  pname = "snacks.nvim";
  version = "2024-11-14";
  src = fetchFromGitHub {
    owner = "folke";
    repo = "snacks.nvim";
    rev = "f126609b57c0ec07cfd7bcef7085e3905adb4d42";
    sha256 = "sha256-VpgZbCf1j2uyg8d4olQYm+GWkaWnFPwCSWOZ/2Jm0Us=";
  };
  meta.homepage = "https://github.com/folke/snacks.nvim/";
}

