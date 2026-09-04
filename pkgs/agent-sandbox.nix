{
  writeShellApplication,
  python3,
  git,
  apple-container,
}:
writeShellApplication {
  name = "agent-sandbox";
  runtimeInputs = [
    git
    apple-container
  ];
  text = ''exec ${python3}/bin/python3 ${../scripts/agent-sandbox.py} "$@"'';
}
