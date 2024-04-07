"
This file is compiled into env.lua to bootstrap fennel and load paths
"

(fn file-exists?
  [filepath]
  "
  Duplicates the lib/files.fnl impl but needed before fennel has loaded
  Determine if a file exists and is readable.
  Takes a file path string
  Returns true if file is readable
  "
  (let [file (io.open filepath "r")]
    (when file
      (io.close file))
    (~= file nil)))

(local script-path (hs.spoons.scriptPath))
(local paths-file (hs.spoons.resourcePath "paths.lua"))

(fn butlast
  [tbl]
  (let [total (- (length tbl) 1)]
    (faccumulate
      [new-tbl []
       i 1 total 1]
      (do
        (table.insert new-tbl (. tbl i))
        new-tbl))))

(fn dirname
  [filepath]
  (-> (faccumulate [state {:paths []
                           :path ""}
                    i 1 (length filepath) 1]
       (let [char (filepath:sub i i)]
         (if (= char "/")
           (do
             (table.insert state.paths state.path)
             (tset state :path ""))
           (do 
             (tset state :path (.. state.path char))))
         state))
      (. :paths)
      (butlast)
      (table.concat "/")))

(when (and (not _G.fennel-installed)
           (not (file-exists? paths-file)))
  (let [file (io.open paths-file "w")
        homedir (os.getenv "HOME")
        customdir (.. homedir "/.spacehammer")]
    (file:write 
      "return {\n"
      (.. "  customdir = '" customdir "',\n")
      (.. "  fennel = '" script-path "vendor/fennel.lua"  "'\n")
      "};\n")
    (file:flush)
    (file:close)))

(local paths (dofile paths-file))
(local fennel (dofile paths.fennel))

(when (not _G.fennel-installed)
  (let [src-path (dirname script-path)]
    (print package.path)
    (tset package :path (.. src-path "/?.lua;"
                            src-path "/?/init.lua;"
                            package.path))

    (tset fennel :path (.. src-path "/?.fnl;" 
                           src-path "/?/init.fnl;" 
                           fennel.path))

    (tset fennel :macro-path (.. src-path "/?.fnl;" src-path "/?/init-macros.fnl;" fennel.macro-path))

    (fennel.install)
  
    (set _G.fennel-installed true)))

{: fennel
 : paths}
