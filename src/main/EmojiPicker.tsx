import { bind, Variable } from "astal";
import { Astal, Gtk, Gdk, App } from "astal/gtk3";
import { exec, subprocess } from "astal/process";

// constants
const LABEL_WIDTH = 20;
const SCREEN_HEIGHT = Gdk.Screen.get_default()?.get_height() || 0;
const WIDGET_HEIGHT = Math.floor(SCREEN_HEIGHT / 2);
const WIDGET_WIDTH = (WIDGET_HEIGHT * 4) / 3;
const LABEL_PER_ROW = Math.floor(WIDGET_WIDTH / LABEL_WIDTH);

// methods
const getLabels = (emojis: Emoji[]) => {
  const rows = Math.ceil(emojis.length / LABEL_PER_ROW);
  const labels: Emoji[][] = [];
  for (let i = 0; i < rows; i++) {
    labels.push(emojis.slice(i * LABEL_PER_ROW, (i + 1) * LABEL_PER_ROW));
  }

  return labels;
};

// main
const EmojiPicker = (emojis: Emoji[]) => {
  const searchText = Variable("");
  const filteredEmojis = Variable(emojis);
  const labels = Variable<Emoji[][]>(getLabels(emojis));

  const windowSetup = () => {
    searchText.subscribe((search) => {
      filteredEmojis.set(
        emojis.filter((emoji) => {
          const sanitizedText = search.toLowerCase();
          return (
            emoji.slug.includes(sanitizedText) ||
            emoji.unicodeName.toLowerCase().includes(sanitizedText)
          );
        }),
      );
    });

    filteredEmojis.subscribe((newEmojis) => {
      labels.set(getLabels(newEmojis));
    });
  };

  const handleClick = (emoji: Emoji) => {
    subprocess(
      ["bash", "-c", `wl-copy ${emoji.character}; echo ${emoji.character}`],
      () => {
        const activeWindow = JSON.parse(exec("hyprctl -j activewindow"));
        exec(`hyprctl dispatch focuswindow address:${activeWindow.address}`);
        exec([
          "bash",
          "-c",
          "YDOTOOL_SOCKET=/tmp/.ydotool_socket ydotool key 29:1 42:1 47:1 29:0 42:0 47:0",
        ]);
      },
    );
  };

  return (
    <window
      setup={windowSetup}
      name="Emojis"
      application={App}
      keymode={Astal.Keymode.ON_DEMAND}
      layer={Astal.Layer.TOP}
      onKeyPressEvent={(self, event) => {
        const key = event.get_keyval()[1];
        if (key === Gdk.KEY_Escape) {
          self.set_visible(false);
        }
      }}
      isFocus={false}
    >
      <box vertical>
        <entry
          onChanged={(self) => {
            searchText.set(self.text);
          }}
        />
        <scrollable
          widthRequest={WIDGET_WIDTH}
          heightRequest={WIDGET_HEIGHT}
          hscroll={Gtk.PolicyType.NEVER}
          vscroll={Gtk.PolicyType.AUTOMATIC}
        >
          <box vertical>
            {bind(labels).as((labels) => {
              return labels.map((emojis) => {
                return (
                  <box halign={Gtk.Align.CENTER}>
                    {emojis.map((emoji) => {
                      return (
                        <eventbox
                          className="emoji"
                          onClick={() => {
                            handleClick(emoji);
                          }}
                          widthRequest={LABEL_WIDTH}
                        >
                          {emoji.character}
                        </eventbox>
                      );
                    })}
                  </box>
                );
              });
            })}
          </box>
        </scrollable>
      </box>
    </window>
  );
};

export default EmojiPicker;
