{ ... }:

{
  programs.ripgrep = {
    enable = true;
    arguments = [
      "--colors=line:fg:yellow"
      "--colors=line:style:bold"
      "--colors=path:fg:green"
      "--colors=path:style:bold"
      "--colors=match:fg:black"
      "--colors=match:bg:yellow"
      "--colors=match:style:nobold"
    ];
  };
}
