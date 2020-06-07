if exists('g:_loaded_plugin')
    finish
endif

let s:cpo_save = &cpo | set cpo&vim

let s:plugins = { "levouh/vim-plugin" : "master" }

fu! s:plugin_install(bang) abort " {{{2
    " The directory where each plugin will be installed
    let plugins_dir = substitute(&packpath, ",.*", "", "") .. "/pack/plugins/opt"

    if a:bang
        " If the command that calls this function is called with a <bang>, we will
        " override any local changes and 'hard reinstall' each plugin
        let override = "(git reset --hard HEAD && git clean -f -d); "

        " Remove all directories that exist, but aren't listed as one of
        " the entries in the "s:plugins" dictionary
        call s:plugin_clean()
    else
        let override = ""
    endif

    " Keep track of the number of plugins that are installed for a useful
    " message later
    let num_installed = 0

    " Ensure that the directory to install plugins in exists
    silent! call mkdir(plugins_dir, 'p')

    for [plugin, branch] in items(s:plugins)
        " Form the name of the plugin from the github 'url'.
        " Cloning of the plugin will be done into a directory matching this name,
        " so note that two plugins cannot have the same 'name'
        let plugin_name = s:plugin_name(plugin)
        let plugin_dir = plugins_dir .. "/" .. plugin_name
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

fu! s:plugin_clean(plugins_dir) abort " {{{2
    " Get a list of all plugins that already exist
    let existing_plugins = systemlist("find " .. a:plugins_dir .. " -type d -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null")
    let plugins_to_remove = []

    for plugin in existing_plugins
        if !has_key(s:plugins, plugin)
            call add(plugins_to_remove, plugin)
        endif
    endfor

    let plugin_list = join(plugins_to_remove, ' ')

    if empty(plugin_list)
        " Nothing to remove
        return
    endif

    let user_confirm = input("Remove: " .. plugin_list .. "\n [y/n]?")

    " Regex match in a case-insensitive manner, so 'y/Y' will work
    if l:choice =~? 'y'
        let num_removed = 0

        for plugin in plugins_to_remove
            let plugin_dir = a:plugins_dir .. "/" .. plugin_name
            let num_removed += 1
        endfor

        redraw | echohl WarningMsg | echo "Removed  " .. num_removed .. " plugin(s)" | echohl None
    endif
endfu

fu! s:plugin(bang, plugin, ...) abort " {{{2
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

fu! s:plugin_name(plugin) abort " {{{2
    " Get the name of the plugin from a github 'url'
    "
    " This will be something like:
    "   levouh/vim-plugin
    " from which this function will return:
    "   vim-plugin
    return substitute(a:plugin, ".*\/", "", "")
endfu

command! -bar PluginClean call <SID>plugin_clean()
command! -bang -bar PluginInstall call <SID>plugin_install(<bang>0)
command! -bang -bar -nargs=+ Plugin call <SID>plugin(<bang>0, <f-args>)

let g:_loaded_plugin = 1

let &cpo = s:cpo_save | unlet s:cpo_save
