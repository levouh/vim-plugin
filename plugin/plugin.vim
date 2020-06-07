if exists('g:_loaded_plugin')
    finish
endif

let s:cpo_save = &cpo | set cpo&vim

" The directory where each plugin will be installed
let s:plugins_dir = substitute(&packpath, ",.*", "", "") .. "/pack/plugins/opt"
let s:plugins = { "levouh/vim-plugin" : "master" }

fu! s:plugin_install(bang) abort " {{{1
    let override = ""

    if a:bang
        " If the command that calls this function is called with a <bang>, we will
        " override any local changes and 'hard reinstall' each plugin
        let override = "(git reset --hard HEAD && git clean -f -d); "

        " Remove all directories that exist, but aren't listed as one of
        " the entries in the "s:plugins" dictionary
        call s:plugin_clean()
    endif

    " Keep track of the number of plugins that are installed for a useful
    " message later
    let num_installed = 0

    " Ensure that the directory to install plugins in exists
    silent! call mkdir(s:plugins_dir, 'p')

    for [plugin, branch] in items(s:plugins)
        redraw | echohl WarningMsg | echo "Installing " .. plugin | echohl None

        " Form the name of the plugin from the github 'url'.
        " Cloning of the plugin will be done into a directory matching this name,
        " so note that two plugins cannot have the same 'name'
        let plugin_name = s:plugin_name(plugin)
        let plugin_dir = s:plugins_dir .. "/" .. plugin_name
        let github_url = "https://github.com/" .. plugin

        call system("git clone --recurse-submodules --depth=1 -b " .. branch .. " --single-branch " .. github_url ..
            \ " " .. plugin_dir .." 2> /dev/null || (cd " .. plugin_dir .. " ; " .. override .. "git pull)")

        exe "packadd " .. plugin_name

        let num_installed += 1
    endfor

    " Rebuild helptags if they are provided by these plugins via a 'doc' folder
    silent! helptags ALL

    redraw | echohl WarningMsg | echo "Installed " .. num_installed .. " plugin(s)" | echohl None
endfu

fu! s:plugin_clean() abort " {{{1
    " Get a list of all plugins that already exist, but note that this is
    " only the directory. The keys in the "s:plugins" dictionary will be the full
    " github 'url'.
    let existing_plugins = systemlist("find " .. s:plugins_dir .. " -type d -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null")
    let plugins_to_remove = []

    " The list of all plugins that _should_ be installed
    let plugin_list = map(keys(s:plugins), 's:plugin_name(v:val)')

    for plugin in existing_plugins
        " The directory exists, but it is not listed as a global plugin
        if index(plugin_list, plugin) == -1
            call add(plugins_to_remove, plugin)
        endif
    endfor

    let plugin_list = join(plugins_to_remove, "\t\n")

    if empty(plugin_list)
        " Nothing to remove
        return
    endif

    let choice = input("Remove:\n" .. plugin_list .. "\n[y/n]? ")

    " Regex match in a case-insensitive manner, so 'y/Y' will work
    if choice =~? 'y'
        let cmd = 'rm -r ' .. join(map(plugins_to_remove, 's:plugins_dir .. "/" .. v:val'), ' ')
        call system(cmd)

        redraw | echohl WarningMsg | echo "Removed  " .. len(plugins_to_remove) .. " plugin(s)" | echohl None
    endif
endfu

fu! s:plugin(bang, plugin, ...) abort " {{{1
    " Track that a plugin should be installed
    let s:plugins[a:plugin] = get(a:, 1, "master")
    "               │
    "               └ this will be a github 'url'

    if !a:bang
        " Let Vim do the rest of the work by adding it to
        " the ":h runtimepath"
        exe "silent! packadd " .. s:plugin_name(a:plugin)
    endif
endfu

fu! s:plugin_name(plugin) abort " {{{1
    " Get the name of the plugin from a github 'url'
    "
    " This will be something like:
    "   levouh/vim-plugin
    " from which this function will return:
    "   vim-plugin
    return substitute(a:plugin, ".*\/", "", "")
endfu

" Commands {{{1
command! -bar PluginClean call <SID>plugin_clean()
command! -bang -bar PluginInstall call <SID>plugin_install(<bang>0)
command! -bang -bar -nargs=+ Plugin call <SID>plugin(<bang>0, <f-args>)

let g:_loaded_plugin = 1

let &cpo = s:cpo_save | unlet s:cpo_save
