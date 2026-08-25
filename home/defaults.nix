{ pkgs, ... }:

# Single source of truth for default applications (browser, etc). Add new
# default-app assignments here rather than scattering xdg-mime/BROWSER
# settings across other modules.
{
  home.sessionVariables = {
    BROWSER = "firefox";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
    };
  };
}
