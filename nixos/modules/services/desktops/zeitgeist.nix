# Zeitgeist
{
  config,
  lib,
  pkgs,
  ...
}:
{

  meta = with lib; {
    maintainers = with maintainers; [ ] ++ teams.pantheon.members;
  };

  ###### interface

  options = {
    services.zeitgeist = {
      enable = lib.mkEnableOption "zeitgeist, a service which logs the users' activities and events";
    };
  };

  ###### implementation

  config = lib.mkIf config.services.zeitgeist.enable {

    environment.systemPackages = [ pkgs.zeitgeist ];

    services.dbus.packages = [ pkgs.zeitgeist ];

    systemd.packages = [ pkgs.zeitgeist ];
  };
}
