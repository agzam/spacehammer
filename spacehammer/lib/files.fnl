(local {: contains?
        : split
        : some} (require :spacehammer.lib.functional))

(fn file-exists?
  [filepath]
  "
  Determine if a file exists and is readable.
  Takes a file path string
  Returns true if file is readable
  "
  (let [file (io.open filepath "r")]
    (when file
      (io.close file))
    (~= file nil)))

(fn copy-file
  [source dest]
  "
  Copy the contents of a source file to a destination file.
  Takes a source file path and a destination file path.
  Returns nil
  "
  (let [default-config (io.open source "r")
        custom-config (io.open dest "a")]
    (each [line _ (: default-config :lines)]
      (: custom-config :write (.. line "\n")))
    (: custom-config :close)
    (: default-config :close)))

(fn source-filename?
  [file]
  "
  Determine if a file is not an emacs backup file which starts with \".#\"
  Takes a file path string
  Returns true if it's a source file and not an emacs backup file.
  "
  (not (string.match file ".#")))

(fn source-extension?
  [file]
  "
  Determine if a file is a .fnl or .lua file
  Takes a file string
  Returns true if file extension ends in .fnl or .lua
  "
  (let [ext (split "%p" file)]
    (and
     (or (contains? "fnl" ext)
         (contains? "lua" ext))
     (not (string.match file "-test%..*$")))))

(fn source-updated?
  [file]
  "
  Determine if a file is a valid source file that we can load
  Takes a file string path
  Returns true if file is not an emacs backup and is a .fnl or .lua type.
  "
  (and (source-filename? file)
       (source-extension? file)))

(fn config-reloader
  [files]
  "
  Reload hammerspoon if the list of files contains some hammerspoon or spacehammer source files
  Takes a list of files (intended for use with our config file watcher).
  Performs side effect of reloading hammerspoon.
  Returns nil
  "
  (when (some source-updated? files)
    (hs.alert "Spacehammer reloaded")
    (hs.console.clearConsole)
    (hs.reload)))

(fn watch-files
  [dir]
  "
  Watch a directory of source files. When a file updates we reload hammerspoon.
  Takes a directory to watch.
  Returns a function to stop the watcher.
  "
  (let [watcher (hs.pathwatcher.new dir config-reloader)]
    (: watcher :start)
    (fn []
      (: watcher :stop))))

{: file-exists?
 : copy-file
 : watch-files}
