let CMAKE = "cmake"
let CPPCLANG = 'clang++'
let NINJA = "Ninja"
let MAKE = "make"
let CCLANG = "clang"
let GCC = "gcc"
let GPP = "g++"
let MING_EXTRA = "-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_FIND_ROOT_PATH=/usr/i686-w64-mingw32/ -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY"
let ASAN_SUPP = getcwd() . "/asan.supp"
let LSAN_SUPP = getcwd() . "/lsan.supp"
let MSAN_BLACK_LIST = getcwd() . "/msan.blacklist"

let CMAKE_TYPE = 0
let BUILD_DIRECTORY = "cmake-build-debug"
let CPPCOMPILER = g:CPPCLANG
let CCOMPILER = g:CCLANG
let BUILD_TYPE = "Debug"
let EXTRA_CONFIG = "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
let GENERATOR = g:NINJA

function! s:setType(val, cmakeBuildBir, cCompiler, cppCompiler, buildType, extra, generator)
	let g:CMAKE_TYPE = a:val
	let g:BUILD_DIRECTORY = a:cmakeBuildBir
	let g:CCOMPILER = a:cCompiler
	let g:CPPCOMPILER = a:cppCompiler
	let g:BUILD_TYPE = a:buildType
	let g:EXTRA_CONFIG = a:extra
	let g:GENERATOR = a:generator
endfunction

function! s:getBuildCommand()
	let s:command =  g:CMAKE . " -DCMAKE_BUILD_TYPE=" . g:BUILD_TYPE . " -DCMAKE_C_COMPILER=".g:CCOMPILER . " -DCMAKE_CXX_COMPILER=" . g:CPPCOMPILER . " -G " . g:GENERATOR . " " . g:EXTRA_CONFIG . " --build ../"
	return s:command
endfunction

function! s:Rebuild()
	call AppendExternal("rm -r ./" . g:BUILD_DIRECTORY)
	call AppendExternal("mkdir ./" . g:BUILD_DIRECTORY)
	call AppendInternal(":lcd " . g:BUILD_DIRECTORY)
	call AppendRunAndOpenOnFailure(s:getBuildCommand())
	call AppendInternal(":lcd ../")
endfunction

function! s:RunTest(param, executible, args)
	call s:SilentRun(a:param, a:executible, a:args)
	call AppendOpenLast()
	call AppendRunOnFailureInternal("call ParseClangOutput()")
	call AppendRunOnNamedInternal("call RunOnBuffer()", "run")
	call AppendRunOnNamedInternal("call ApplyTestSyntax()", "run")
	call AppendRunOnNamedInternal("call ColorizeLog()", "run")
	call AppendRunOnNamedInternal(":lcd ".g:BUILD_DIRECTORY,"run")
	call AppendRunOnNamedInternal(":w", "run")
	call AppendOpenErrorFileIfExist()
	call AppendInternal("call AsanParseBuffer()")
	silent call AppendRunOnNamedInternal(":w", "run")
endfunction

function! s:silentBuild(target)
	let s:build = g:CMAKE . " --build " . g:BUILD_DIRECTORY . " --target " . a:target . " -- -j 4"
	call AppendExternal(s:build)
endfunction

function! s:SilentRun(target, executible, args)
	call s:silentBuild(a:target)

	let s:exec = " ./" . g:BUILD_DIRECTORY . "/" . a:executible . " " . a:args
	call AppendRunOnSuccessExternal(s:exec, "run")
endfunction

function! s:Run(param, executible, args)
	call s:SilentRun(a:param, a:executible, a:args)
	call AppendOpenLast()
	call AppendRunOnFailureInternal("call ParseClangOutput()")
	call AppendRunOnNamedInternal("call ColorizeLog()", "run")
	call AppendOpenErrorFileIfExist()
	call AppendInternal("call AsanParseBuffer()")
	silent call AppendRunOnNamedInternal(":w", "run")
endfunction

function! s:RunD(target, executible, args)
	let s:exec = "./" . g:BUILD_DIRECTORY . "/" . a:executible . " " . a:args

	call s:silentBuild(a:target)
	call AppendOpenOnFailure()
	call AppendRunOnFailureInternal("call ParseClangOutput()")
	call AppendRunOnSuccessInternal("ConqueGdb -ex=r --args " . s:exec)
	call AppendRunOnSuccessInternal(":lcd ".g:BUILD_DIRECTORY)

endfunction

function! s:coverage(val, cmakeBuildBir, cCompiler, cppCompiler, buildType, extra, generator)
	silent call s:setType(a:val, a:cmakeBuildBir, a:cCompiler, a:cppCompiler, a:buildType, a:extra, a:generator)
	"silent call s:Rebuild()
	silent let s:build = g:CMAKE . " --build " . g:BUILD_DIRECTORY . " --target runTest -- -j 4"
	silent call AppendRunOnSuccessExternal(s:build)
	call AppendOpenOnFailure()
	silent call AppendRunOnSuccessExternal("bash coverage.sh")
endfunction

function! s:generateCompilationDatabase()
	silent execute "!rm -r cmake-build-cdatabase/" 
	silent execute "!mkdir cmake-build-cdatabase" 
	silent execute "!rm compile_commands.json"
	execute "!cd cmake-build-cdatabase/ ; " . g:CMAKE . " ../ -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -DCMAKE_BUILD_TYPE=Debug; mv compile_commands.json ../"
endfunction

function! s:goToTest(name)
	execute "vimgrep " . a:name . " ../test/**/*.cpp"	. " test/**/*.cpp"
endfunction

command! -nargs=0 CMDEBUG call s:setType(0, "cmake-build-debug-clang", g:CCLANG, g:CPPCLANG, "Debug", "", g:NINJA)
command! -nargs=0 CMRELEASE call s:setType(1, "cmake-build-release-clang", g:CCLANG, g:CPPCLANG, "Release", "", g:NINJA)
command! -nargs=0 CMASAN call s:setType(2, "cmake-build-asan", g:CCLANG, g:CPPCLANG, "Debug", "-DPROJ_ASAN=ON ", g:NINJA)
command! -nargs=0 CMTSAN call s:setType(3, "cmake-build-tsan", g:CCLANG, g:CPPCLANG, "Debug", "-DPROJ_TSAN=ON ", g:NINJA)
command! -nargs=0 CMUBSAN call s:setType(4, "cmake-build-ubsan", g:CCLANG, g:CPPCLANG, "Debug", "-DPROJ_UBSAN=ON ", g:NINJA)
command! -nargs=0 CMMSAN call s:setType(5, "cmake-build-msan", g:CCLANG, g:CPPCLANG, "Debug", "-DPROJ_MSAN=ON -fsanitize-blacklist=" . g:MSAN_BLACK_LIST, g:NINJA)
command! -nargs=0 CMWINDOWS call s:setType(6, "cmake-build-release-windows", "/usr/bin/x86_64-w64-mingw32-gcc-posix", "/usr/bin/x86_64-w64-mingw32-c++-posix", "Release", g:MING_EXTRA, g:NINJA)
command! -nargs=0 COVERAGE call s:coverage(7, "cmake-build-coverage", g:GCC, g:GPP, "Debug", "-DPROJ_COVERAGE=ON", g:NINJA)

command! -nargs=0 REBUILD call s:Rebuild()
command! -nargs=0 TALL call s:RunTest("runTest", "test/runTest", "")
command! -nargs=0 TSUIT call s:RunTest("runTest", "test/runTest", GTestOption(1))
command! -nargs=0 TONE call s:RunTest("runTest", "test/runTest", GTestOption(0))
command! -nargs=0 RUN call s:Run("main", "main", "")
command! -nargs=0 DTALL call s:RunD("runTest", "test/runTest", "")
command! -nargs=0 DTSUIT call s:RunD("runTest", "test/runTest", GTestOption(1))
command! -nargs=0 DTONE call s:RunD("runTest", "test/runTest", GTestOption(0))
command! -nargs=0 DRUN call s:RunD("main", "main", "")
command! -nargs=0 CCGENERATE call s:generateCompilationDatabase()
command! -nargs=0 GOTOTEST call s:goToTest(expand("<cword>"))
command! -nargs=0 CHANGEDIR call s:switchDir()
command! -nargs=* AddClass call s:addClass(<f-args>)
command! -nargs=* AddTest call s:addTest(<f-args>)

nnoremap <leader><leader>gt :vsp<cr>:GOTOTEST<cr>
nnoremap <leader><leader>b :REBUILD<cr>
nnoremap <leader><leader>r :RUN<cr>
nnoremap <leader><leader>dr :DRUN<cr>
nnoremap <leader><leader>ta :TALL<cr>
nnoremap <leader><leader>dta :DTALL<cr>
nnoremap <leader><leader>ts :TSUIT<cr>
nnoremap <leader><leader>dts :DTSUIT<cr>
nnoremap <leader><leader>to :TONE<cr>
nnoremap <leader><leader>dto :DTONE<cr>
nnoremap <leader><leader>s :SyntasticToggleMode<cr>
nnoremap <leader><leader>cd :CHANGEDIR<cr>

let $ASAN_OPTIONS="suppressions=".g:ASAN_SUPP
let $LSAN_OPTIONS="suppressions=".g:LSAN_SUPP

exe "hi log ctermfg=" .  g:ColorString
exe "hi logFile ctermfg=" . g:ColorType
exe "hi atMethod ctermfg=" . g:ColorStatement
exe "hi logWarning ctermfg=" . g:ColorNumber

function! ColorizeLog()
	syntax match log '\s*\(DEBUG\|INFO\|WARNING\): .*\s*'
	syntax match logWarning '\s*WARNING: .*\s*'
	syntax match atMethod '>.*at'
	syntax match logFile ':\s\+\S\+\s*'
endfunction

function! s:findPathToTarget(folder, newClassName)
endfunction

function! s:addClass(folder, newClassName)
	execute "!echo TARGET_SOURCES\\(".a:folder." PRIVATE src/".a:newClassName."\\) >> game/".a:folder."/CMakeLists.txt"
	execute "vsp ./core/".a:folder."/src/".a:newClassName.".cpp"
	execute "sp ./core/".a:folder."/include/".a:newClassName.".hpp"
	normal icls
endfunction

function! s:addTest(folder, testName)
	execute "!echo TARGET_SOURCES\\(runTest PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src/".a:testName."\\) >> test/core/".a:folder."/CMakeLists.txt"
	execute "vsp ./test/core/".a:folder."/src/".a:testName.".cpp"
	normal itest

endfunction

exe "hi clangOutError ctermfg="g:ColorStatement
exe "hi clangOutNote ctermfg="g:ColorNumber
exe "hi clangOutFile ctermfg="g:ColorType
exe "hi clangOutFile ctermfg="g:ColorString
function! ParseClangOutput()
	syntax match clangOutError '\s\+error:\s\+'
	syntax match clangOutNote '\s\+note:\s\+'
	syntax match clangOutNote '\s\+warning:\s\+'
	syntax match clangOutFile '\S\+:\d\+:\d\+:'
endfunction

command! -nargs=1 Rename call s:clangRename(<f-args>)

function! s:clangRename(newName)
	let s:offset = line2byte(line(".")) + col(".") - 2
	let command = "clang-rename -offset=" . s:offset . " -i -new-name=" . a:newName . " " . expand('%:t')
	call AppendExternal(command)
	call AppendRunOnSuccessInternal("checktime")
endfunction
