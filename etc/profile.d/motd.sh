if [ ! -z "$TERM" ]; then
  source /etc/os-release
  echo "You are using $PRETTY_NAME | $HOME_URL"
fi
