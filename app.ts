import { App } from "astal/gtk3";
import EmojiPicker from "./src/main/EmojiPicker";
import { readFileAsync } from "astal";
import css from "./style.scss";

App.start({
  requestHandler(request, res) {
    if (request === "open") {
      App.get_window("Emojis")?.set_visible(true);
      return;
    }

    if (request === "close") {
      App.get_window("Emojis")?.set_visible(false);
      return;
    }

    res("unknown command");
  },
  main() {
    readFileAsync("/home/luay/me/projects/emoji-picker/emojis.json")
      .then((content) => {
        const emojis = JSON.parse(content) as Emoji[];
        EmojiPicker(emojis);
      })
      .catch(console.log);
  },
  css,
});
