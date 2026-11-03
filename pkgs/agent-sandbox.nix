{
  writeShellApplication,
  python3,
  git,
  container,
}:
writeShellApplication {
  name = "agent-sandbox";
  runtimeInputs = [
    git
    container
  ];
  text = ''exec ${python3}/bin/python3 ${../scripts/agent-sandbox.py} "$@"'';
}
