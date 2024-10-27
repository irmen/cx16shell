%import shellroutines
%import diskio
%import textio
%import conv
%import emudbg
%launcher none
%option no_sysinit
%zeropage dontuse
%encoding iso
%address $4000

main {
    sub start(){
        shell.chrout('\r')
        ;doc.path_prefix_len = string.length(doc.path);having a constant value'd be probably way better. 
        ;i guess we could turn it into constant once the ultimate location for documents will be decided upon

        ;shell.print_ub(doc.path_prefix_len)

        screen.size()

        str line="\x00"+"?"*254
        ubyte[6] temp

        screen.shellcolors = shell.get_text_colors()
        cx16.rambank(0)
        if string.length(doc.name)==0{
            shell.err_set("No argument provided.\rType a page name or type \"list\" to show all available pages.")
            sys.exit(1)
        }
        while string.isspace(@(doc.name)){
            doc.name++
        }
        ;shell.print_ub(string.length(doc.name))

        ; Added in case x16edit pager mode actually becomes a thing (currently, it's silently ignored by the man)
        if string.startswith(doc.name,"-P"){
            doc.name+=2
            while string.isspace(@(doc.name)){
                doc.name++
            }
            cx16.r0L,void=string.find(doc.name,' ')
            if_cc{
                shell.err_set("No argument provided.\rType a page name or type \"list\" to show all available pages.")
                sys.exit(1)
            }
            doc.name+=cx16.r0L
            while string.isspace(@(doc.name)){
                doc.name++
            }
        }
        if string.startswith(doc.name,"list"){
            if doc.name[4]==0{
                list()
            }
            else{
                doc.name+=4
                while string.isspace(@(doc.name)){
                    doc.name++
                }
                void string.append(doc.path,doc.name)
                list()
            }
            sys.exit(0)
        }
        void string.append(doc.path,doc.name)
        
        if ((not diskio.f_open(doc.path)) and (not checkspecial())){
            ;shell.print(diskio.status())
            void string.append(line, "Page \"")
            void string.append(line, doc.name)
            void string.append(line, "\" doesn't exist.")
            shell.err_set(line)
            sys.exit(1)
        }
        ubyte nctr=0
        repeat{
            void diskio.f_readline(line)
            ubyte i
            ubyte i_no=0
            bool flagged=false
            ubyte mode = 0 
            if line[0]=='@'{
                
                when line[1]{
                    '#' -> {
                        run_directive(&line+2)
                        continue
                    }
                    ';' -> continue
                }
            }
            for i_no in 0 to string.length(line){
                i=line[i_no] ; theoretically wastes cpu cycles, but i really didn't want to rewrite 
                ;everything after i've switched from 
                ;`for i in line` to `for i_no in 0 to string.length(line)`

                if mode & parser_modes.HEX_CHAR !=0 {
                    if mode & parser_modes.EXTENDED !=0 {
                        temp[1]=i
                        temp[2]=0
                        shell.chrout(conv.hex2uword(temp)as ubyte)
                        mode &=~parser_modes.HEX_CHAR
                        mode &=~parser_modes.EXTENDED
                    }
                    else {
                        temp[0]=i
                        mode |=parser_modes.EXTENDED
                    }
                    continue
                }
                if mode & parser_modes.COLOR !=0 {
                    temp[0]=i
                    temp[1]=0
                    color(conv.hex2uword(temp)as ubyte)
                    mode &=~parser_modes.COLOR
                    continue
                }
                if flagged{
                    when i{
                        '@' -> shell.chrout(i)
                        ';' -> break
                        'N','n' -> color(screen.shellcolors[0])
                        'B','b' -> color(screen.shellcolors[1]) ;added in the last minute, lol
                        'H','h' -> color(screen.shellcolors[2])
                        'P','p' -> color(screen.shellcolors[3])
                        'E','e' -> color(screen.shellcolors[4])
                        'C','c' -> mode |=parser_modes.COLOR
                        'X','x','U','u' -> mode |= parser_modes.HEX_CHAR
                        else -> {
                            shell.print("\x1c\x01\x96@")
                            color(screen.shellcolors[1])
                            shell.chrout(1)
                            color(screen.shellcolors[0])
                        }
                    }
                    flagged=false
                    continue
                }
                if i=='@'{
                    flagged=true
                    continue
                }
                shell.chrout(i)
                if string.isspace(i){
                    temp[0] = txt.get_column()+1
                    temp[3]=i_no+1

                    while temp[0]<=screen.size.x{
                        if string.isspace(line[temp[3]]) or line[temp[3]]==0{
                            break
                        }
                        if not line[temp[3]]=='@'{
                            temp[3]++
                            temp[0]++
                            continue
                        }
                        when line[temp[3]+1]{
                            '@' -> {
                                temp[3]+=2
                                temp[0]++
                            }
                            ';' -> {
                                break
                            }
                            'N','n','H','h','P','p','E','e','B','b' -> {
                                temp[3]+=2
                            }
                            'C','c' -> {
                                temp[3]+=3
                            }

                            'X','x','U','u' -> {
                                temp[3]+=4
                                when line[temp[3]+2]{
                                    '0','1','8','9'->{

                                    }
                                    else -> {
                                        temp[0]++
                                    }
                                }
                            }
                            else -> {
                                temp[3]+=2
                                temp[0]++
                            }
                        }
                    }
                    if temp[0]>=screen.size.x{
                        shell.chrout('\r')
                        nctr++
                        if nctr >= screen.size.y-2{
                            main.run_directive.pause()
                            nctr=0
                        }
                    }
                }
            }
            if cbm.READST() & 64 !=0 {
                break
            }
            shell.chrout('\r')
            nctr++
            if nctr >= screen.size.y-2{
                main.run_directive.pause()
                nctr=0
            }

        }
        diskio.f_close()
        shell.chrout('\r')
    }

    asmsub color(ubyte txtcol @X) clobbers(A){
        %asm{{
            jsr p8s_colorchar
            jmp cbm.CHROUT
        }}
    }

    asmsub colorchar(ubyte txtcol @X)-> ubyte @A{
        %asm{{
            lda color_to_charcode,x
            rts
        color_to_charcode	.byte  $90, $05, $1c, $9f, $9c, $1e, $1f, $9e, $81, $95, $96, $97, $98, $99, $9a, $9b
            ; !notreached!
        }}
    }

    sub run_directive(str dir){
        str err_msg="Directive error: \x00"+("?"*45)
        err_msg[17]=0
        ubyte argstart
        bool hasarg
        argstart, hasarg = string.find(dir,':')
        argstart++
        while string.isspace(@(dir+argstart)){
            argstart++
        }
        when dir[0]{
            'R','r'-> switch_file(dir+argstart)
            'A','a' -> alias(dir+argstart)
            'P','p' -> pause()
            'C','c' -> {
                shell.print_ubhex(@(dir+argstart),true)
                shell.chrout('\r')
            }
            else -> {
                incorrect()
            }
        }
        sub switch_file(str file) {
            if not hasarg{
                void string.append(err_msg, "incorrect syntax (lack of ?")
                err_msg[string.length(err_msg)-1]=main.colorchar(screen.shellcolors[2])
                void string.append(err_msg, ":?)")
                err_msg[string.length(err_msg)-2]=main.colorchar(screen.shellcolors[4])
                shell.err_set(err_msg)
                return
            }
            diskio.f_close()
            doc.path[doc.path_prefix_len]=0
            void string.append(doc.path,file)
            if ((not diskio.f_open(doc.path)) and (not checkspecial())){
                void string.append(err_msg,"Page \"")
                void string.append(err_msg,file)
                void string.append(err_msg,"\" couldn't be loaded")
                shell.err_set(err_msg)
                sys.exit(1)
            }
            doc.name=$bf00
            void string.copy(file,doc.name)
            
        }

        sub alias(str file){
            color(screen.shellcolors[2])
            shell.print(doc.name)
            color(screen.shellcolors[0])
            shell.print(" is an alias to ")
            color(screen.shellcolors[2])
            shell.print(file)
            color(screen.shellcolors[0])
            shell.print(". \rHere's the content of that page: \r\r")
            switch_file(file)
        }

        sub incorrect(){
            void string.copy("...\x00",dir+10)
            void string.append(err_msg,"\"")
            void string.append(err_msg,dir)
            void string.append(err_msg,"\" is not a correct directive")
            shell.err_set(err_msg)
            return
        }
        sub pause() {
            shell.print("\x01Press any key to continue\x01")
            cbm.CLRCHN()
            cbm.kbdbuf_clear()
            while cbm.GETIN2()==0 {
                ; wait for key
            }
            diskio.reset_read_channel()
            shell.chrout('\r')
        }
    }

    sub list(){
        cx16.rambank(1)
        cbm.SETNAM(7, petscii:"$=c:*=d")
        cbm.SETLFS(12, diskio.drivenumber, 0)
        ubyte status = 1
        void cbm.OPEN()          ; open 12,8,0,"$=c:*=d"
        if_cs
            goto io_error
        void cbm.CHKIN(12)        ; use #12 as input channel
        if_cs
            goto io_error
        
        while cbm.CHRIN()!='"' {
            ; skip up to entry name
        }
        bool first_line_diskname=true
        status = cbm.READST()
        cx16.r0 = $a000-1
        while status==0 {
            repeat {
                cx16.r0++
                @(cx16.r0) = cbm.CHRIN()
                if @(cx16.r0)=='"'{
                    @(cx16.r0)=0
                    break
                }
                
            }
            if (first_line_diskname){
                cx16.r0 = $a000-1
            }
            first_line_diskname=false
            while cbm.CHRIN()!='"' and status==0 {
                status = cbm.READST()
                ; skipping up to next entry name
            }
        }
        uword pwdptr=cx16.r0
        status = cbm.READST()
    io_error:
        cbm.CLRCHN()        ; restore default i/o devices
        cbm.CLOSE(12)

        if status!=0 and status & $40 == 0{            ; bit 6=end of file
            shell.err_set("IO error")
            return 
        }
        diskio.chdir(doc.path)
        if conv.str2ubyte(diskio.status())!=0{
            shell.err_set("Specified page doesn't exist or doesn't support having subpages.")
            return
        }
        void diskio.lf_start_list("*")
        while diskio.lf_next_entry(){
            if (diskio.list_filename == "." or diskio.list_filename == "..") continue
            main.start.temp[1]=0
            main.start.temp[0]=txt.get_column()+1
            if (string.length(diskio.list_filename)>screen.size.x-main.start.temp[0]) {
                shell.chrout('\r')
            }
            
            shell.print(diskio.list_filename)
            
            if diskio.list_filetype == petscii:"dir"{
                color(screen.shellcolors[3])
                shell.chrout('/')
                color(screen.shellcolors[0])
                main.start.temp[1]=1
            }
            if diskio.list_filename == "1"{
                color(screen.shellcolors[2])
                shell.print("(index)")
                color(screen.shellcolors[0])
                main.start.temp[1]=string.length("(index)")
            }
            ubyte spcs=10
            while (string.length(diskio.list_filename)+main.start.temp[1])>spcs{
                spcs*=2
            }
            repeat ((spcs-1)-(string.length(diskio.list_filename)+main.start.temp[1]))+1{
                shell.chrout(' ')
            }
        }
        shell.chrout('\r')
        pwdptr--
        while pwdptr>=$a000 {
            while @(pwdptr)!=0 and pwdptr>=$a000{
                pwdptr--
            }
            diskio.chdir(pwdptr+1)
            pwdptr--
        }
    }
    
    sub checkspecial() -> bool{
        if string.endswith(doc.path,"/"){
            doc.path[string.length(doc.path)-1]=0
            if diskio.f_open(doc.path){
                return true
            }
        }
        
        if string.endswith(doc.path,"cfgs"){
            doc.path[string.length(doc.path)-1]=0
        }
        else if string.endswith(doc.path,"5"){
            doc.path[string.length(doc.path)-1]=0
            void string.append(doc.path,"cfg")
        }
        else if string.endswith(doc.path,"configs"){
            doc.path[string.length(doc.path)-7]=0
            void string.append(doc.path,"cfg")
        }
        else if string.endswith(doc.path,"config"){
            doc.path[string.length(doc.path)-6]=0
            void string.append(doc.path,"cfg")
        }
        else if string.endswith(doc.path,"conf"){
            doc.path[string.length(doc.path)-4]=0
            void string.append(doc.path,"cfg")
        }
        if diskio.f_open(doc.path){
            return true
        }
        void string.append(doc.path,"/1")
        if (diskio.f_open(doc.path)) return true
        else return false
    }
}
parser_modes{
    const ubyte COLOR=1
    const ubyte HEX_CHAR=2
    const ubyte EXTENDED=$80
    
}
doc{
    str path = "/SHELL-FILES/manpages/\x00"+"?"*160 ;afaik shell.prg blocks longer arg strings anyway
    uword name=$bf00
    const ubyte path_prefix_len = 22
}
screen{
    sub size(){
        ubyte x
        ubyte y
        x,y = cbm.SCREEN()
    }
    uword shellcolors
}
