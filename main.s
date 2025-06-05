.text
.global _main

.equ SYSCALL, 0
.equ EXIT, 1
.equ FORK, 2
.equ READ, 3
.equ WRITE, 4
.equ OPEN, 5
.equ CLOSE, 6
.equ WAIT4, 7
.equ UNLINK, 10
.equ CHDIR, 12
.equ GETPID, 20
.equ IOCTL, 54
.equ SYMLINK, 57
.equ EXECVE, 59
.equ FCNTL, 92
.equ MKDIR, 136
.equ RMDIR, 137
.equ STAT, 188
.equ GETDIRENTRIES, 196

; termios.h
.equ ICANON, 256
.equ ECHO, 8

.equ TERMIOS_SIZE, 72
.equ CLFLAG_OFFSET, 24

; ttycom.h
.equ TIOCGETA, 1078490131
.equ TIOCSETA, 2152231956

; dirent.h
.equ DT_DIR,        4
.equ DT_LNK,        10

; moving around
.equ ASCII_A,       97
.equ ASCII_W,       119
.equ ASCII_S,       115
.equ ASCII_D,       100
.equ ASCII_G,       103
.equ ASCII_G_CAP,   71

; change workspace
.equ ASCII_1,       49
.equ ASCII_2,       50

; commands
.equ ASCII_SPACE,   32  ; select entry
.equ ASCII_R,       114 ; remove entry
.equ ASCII_T,       116 ; new file
.equ ASCII_M,       109 ; new dir
.equ ASCII_L,       108 ; symlink
.equ ASCII_C,       99  ; copy
.equ ASCII_C_CAP,   67  ; move
.equ ASCII_E,       101 ; edit

; exit
.equ ASCII_Q,       113

_main:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    ; termios

    adrp x20, termios_new@PAGE
    add x20, x20, termios_new@PAGEOFF

    adrp x21, termios@PAGE
    add x21, x21, termios@PAGEOFF

    mov x16, IOCTL
    mov x0, #0
    ldr x1, =TIOCGETA
    mov x2, x21
    svc SYSCALL

    mov x3, #0

    b copy_old_termios

copy_old_termios:
    cmp x3, #TERMIOS_SIZE
    beq create_termios_new
    ldrb w4, [x21, x3]
    strb w4, [x20, x3]
    add x3, x3, #1
    b copy_old_termios

create_termios_new:
    ldr x3, [x20, #CLFLAG_OFFSET]

    mov x4, #ICANON
    orr x4, x4, #ECHO
    mvn x4, x4

    and x3, x3, x4

    str x3, [x20, #CLFLAG_OFFSET]

    b set_termios

set_termios:
    ; hide cursor
    mov x16, WRITE
    mov x0, #1
    adrp x1, hide_cursor@PAGE
    add x1, x1, hide_cursor@PAGEOFF
    ldr x2, =6
    svc SYSCALL

    mov x16, IOCTL
    mov x0, #0
    ldr x1, =TIOCSETA
    adrp x2, termios_new@PAGE
    add x2, x2, termios_new@PAGEOFF
    svc SYSCALL

    b open_dir

set_termios_old:
    ; show cursor
    mov x16, WRITE
    mov x0, #1
    adrp x1, show_cursor@PAGE
    add x1, x1, show_cursor@PAGEOFF
    ldr x2, =6
    svc SYSCALL

    mov x16, IOCTL
    mov x0, #0
    ldr x1, =TIOCSETA
    adrp x2, termios@PAGE
    add x2, x2, termios@PAGEOFF
    svc SYSCALL

    b get_input

get_input:
    ; read stdin
    mov x16, READ
    mov x0, #0
    adrp x1, input@PAGE
    add x1, x1, input@PAGEOFF
    mov x2, #1024
    svc SYSCALL

    mov x4, x0

    ; check input
    adrp x0, input@PAGE
    add x0, x0, input@PAGEOFF
    ldrb w1, [x0]

    cmp x3, #1
    beq new_file_entry

    cmp x3, #2
    beq new_dir_entry

    cmp x3, #3
    beq new_symlink_entry

    cmp x3, #4
    beq copy_entry

    cmp x3, #5
    beq copy_entry

    cmp w1, #ASCII_Q
    beq exit

    cmp w1, #ASCII_S
    beq next_entry_index

    cmp w1, #ASCII_W
    beq prev_entry_index

    cmp w1, #ASCII_A
    beq set_prev_dir

    cmp w1, #ASCII_D
    beq set_next_dir

    cmp w1, #ASCII_G
    beq jump_to_first

    cmp w1, #ASCII_G_CAP
    beq jump_to_last

    cmp w1, #ASCII_1
    beq change_workspaces

    cmp w1, #ASCII_2
    beq change_workspaces

    cmp w1, #ASCII_SPACE
    beq select_entry

    cmp w1, #ASCII_R
    beq remove_entry

    cmp w1, #ASCII_T
    beq prompt_new_file_entry

    cmp w1, #ASCII_M
    beq prompt_new_dir_entry

    cmp w1, #ASCII_L
    beq prompt_new_symlink_entry

    cmp w1, #ASCII_C
    beq prompt_copy_entry

    cmp w1, #ASCII_C_CAP
    beq prompt_move_entry

    cmp w1, ASCII_E
    beq edit_entry

    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

open_dir:
    ; open cwd
    mov x16, OPEN
    adrp x0, cwd@PAGE
    add x0, x0, cwd@PAGEOFF
    mov x1, #0
    mov x2, #0
    svc SYSCALL

    ; get fd
    mov x19, x0

    ; allocate buffer for getdirentries
    sub sp, sp, #4095
    mov x20, sp

    ; allocate buffer for offstack
    sub sp, sp, #8
    mov x21, sp
    str xzr, [x21]

get_entries:
    ; getdirentries
    mov x16, GETDIRENTRIES
    mov x0, x19
    mov x1, x20
    mov x2, #4095
    mov x3, x21
    svc SYSCALL

    mov x22, x0
    mov x23, x20

    ; entry count
    mov x25, #-1

get_entry:
    cmp x22, #20
    blt finished_listing

    ; d_reclen
    ldrh w11, [x23, #16]

    ; d_type
    ldrb w8, [x23, #18]

    ; d_namelen
    ldrb w9, [x23, #19]

    ;d_name
    add x24, x23, #20

    ; increment count
    add x25, x25, #1

    ; check if first entry
    ;cmp x25, #-1
    ;beq next_entry

    adrp x26, entry_index@PAGE
    add x26, x26, entry_index@PAGEOFF
    ldr x27, [x26]

    cmp x25, x27
    beq highlight_entry

    ; check if dir
    cmp w8, #DT_DIR
    beq print_dir_color

    ; check if symlink
    cmp w8, #DT_LNK
    beq print_link_color


print_entry:
    ; print d_name
    mov x16, WRITE
    mov x0, #1
    mov x1, x24
    mov x2, x9
    svc SYSCALL

    ; print newline
    mov x16, WRITE
    mov x0, #1
    adrp x1, newline@PAGE
    add x1, x1, newline@PAGEOFF
    ldr x2, =5
    svc SYSCALL

next_entry:
    add x23, x23, x11
    sub x22, x22, x11
    b get_entry

finished_listing:
    ; check if entry_index is bigger than entry count

    adrp x26, entry_index@PAGE
    add x26, x26, entry_index@PAGEOFF
    ldr x27, [x26]

    cmp x27, x25
    bgt prev_entry_index

    ; close pwd
    mov x16, CLOSE
    mov x0, x19
    svc SYSCALL

    ; print newline
    mov x16, WRITE
    mov x0, #1
    adrp x1, newline@PAGE
    add x1, x1, newline@PAGEOFF
    ldr x2, =5
    svc SYSCALL

    ; highlight selected
    mov x16, WRITE
    mov x0, #1
    adrp x1, highlight_selected@PAGE
    add x1, x1, highlight_selected@PAGEOFF
    ldr x2, =6
    svc SYSCALL

    ; print selected entry
    mov x16, WRITE
    mov x0, #1
    adrp x1, selected_entry@PAGE
    add x1, x1, selected_entry@PAGEOFF
    ldr x2, =1024
    svc SYSCALL

    ; print newline
    mov x16, WRITE
    mov x0, #1
    adrp x1, newline@PAGE
    add x1, x1, newline@PAGEOFF
    ldr x2, =5
    svc SYSCALL

    b get_input

prev_entry_index:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x1, [x0]

    cmp x1, #0
    beq open_dir

    add x1, x1, #-1

    str x1, [x0]

    b open_dir

next_entry_index:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x1, [x0]

    add x1, x1, #1

    str x1, [x0]

    b open_dir

highlight_entry:
    ; highlight entry
    mov x16, WRITE
    mov x0, #1
    adrp x1, highlight_cur@PAGE
    add x1, x1, highlight_cur@PAGEOFF
    ldr x2, =6
    svc SYSCALL

    adrp x0, cur_entry_type@PAGE
    add x0, x0, cur_entry_type@PAGEOFF
    ldr x1, [x0]

    mov x1, x8

    str x1, [x0]

    mov x27, #1024
    adrp x28, cur_entry@PAGE
    add x28, x28, cur_entry@PAGEOFF

clear_cur_entry:
    cbz x27, done_clearing_cur
    mov w13, #0
    strb w13, [x28], #1
    sub x27, x27, #1
    b clear_cur_entry

done_clearing_cur:
    adrp x28, cur_entry@PAGE
    add x28, x28, cur_entry@PAGEOFF

    mov x29, x24
    mov x30, x9
    
copy_to_cur_entry:
    cbz x30, null_term

    ldrb w3, [x29], #1
    strb w3, [x28], #1

    sub x30, x30, #1
   
    b copy_to_cur_entry

null_term:
    mov w3, #0
    strb w3, [x28]

set_entry_path:
    mov x16, OPEN
    adrp x0, cur_entry@PAGE
    add x0, x0, cur_entry@PAGEOFF
    mov x1, #0
    mov x2, #0
    svc SYSCALL

    mov x19, x0

    mov x16, FCNTL
    mov x0, x19
    mov x1, #50
    adrp x2, cur_entry@PAGE
    add x2, x2, cur_entry@PAGEOFF
    svc SYSCALL

    mov x16, CLOSE
    mov x0, x19
    svc SYSCALL

    b print_entry


print_dir_color:
    ; color dir entry
    mov x16, WRITE
    mov x0, #1
    adrp x1, dir_color@PAGE
    add x1, x1, dir_color@PAGEOFF
    ldr x2, =7
    svc SYSCALL

    b print_entry

print_link_color:
    ; color dir entry
    mov x16, WRITE
    mov x0, #1
    adrp x1, link_color@PAGE
    add x1, x1, link_color@PAGEOFF
    ldr x2, =7
    svc SYSCALL

    b print_entry

change_workspaces:
    ; reset entry_index
    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x2, [x0]

    mov x2, #0

    str x2, [x0]

    cmp w1, #ASCII_1
    beq change_workspace_1

    cmp w1, #ASCII_2
    beq change_workspace_2

change_workspace_1:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    adrp x0, cur_workspace@PAGE
    add x0, x0, cur_workspace@PAGEOFF
    ldr x1, [x0]

    mov x1, #0

    str x1, [x0]

    adrp x0, workspace_0@PAGE
    add x0, x0, workspace_0@PAGEOFF
    ldr x1, [x0]

    cmp x1, #0
    beq clear_workspace_1

    b chdir_workspace_1

clear_workspace_1:
    adrp x0, workspace_0@PAGE
    add x0, x0, workspace_0@PAGEOFF

    mov x27, #1024

clear_loop_workspace_1:
    cbz x27, populate_workspace_1
    mov w13, #0
    strb w13, [x0], #1
    sub x27, x27, #1

    b clear_loop_workspace_1

populate_workspace_1:
    mov x16, OPEN
    adrp x0, cwd@PAGE
    add x0, x0, cwd@PAGEOFF
    mov x1, #0
    mov x2, #0
    svc SYSCALL

    mov x19, x0

    mov x16, FCNTL
    mov x0, x19
    mov x1, #50
    adrp x2, workspace_0@PAGE
    add x2, x2, workspace_0@PAGEOFF
    svc SYSCALL

    mov x16, CLOSE
    mov x0, x19
    svc SYSCALL

    b open_dir

chdir_workspace_1:
    mov x16, CHDIR
    adrp x0, workspace_0@PAGE
    add x0, x0, workspace_0@PAGEOFF
    svc SYSCALL

    b open_dir

change_workspace_2:

    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    adrp x0, cur_workspace@PAGE
    add x0, x0, cur_workspace@PAGEOFF
    ldr x1, [x0]

    mov x1, #1

    str x1, [x0]

    adrp x0, workspace_1@PAGE
    add x0, x0, workspace_1@PAGEOFF
    ldr x1, [x0]

    cmp x1, #0
    beq clear_workspace_2

    b chdir_workspace_2

clear_workspace_2:
    adrp x0, workspace_1@PAGE
    add x0, x0, workspace_1@PAGEOFF

    mov x27, #1024

clear_loop_workspace_2:
    cbz x27, populate_workspace_2
    mov w13, #0
    strb w13, [x0], #1
    sub x27, x27, #1

    b clear_loop_workspace_2

populate_workspace_2:
    mov x16, OPEN
    adrp x0, cwd@PAGE
    add x0, x0, cwd@PAGEOFF
    mov x1, #0
    mov x2, #0
    svc SYSCALL

    mov x19, x0

    mov x16, FCNTL
    mov x0, x19
    mov x1, #50
    adrp x2, workspace_1@PAGE
    add x2, x2, workspace_1@PAGEOFF
    svc SYSCALL

    mov x16, CLOSE
    mov x0, x19
    svc SYSCALL

    b open_dir

chdir_workspace_2:
    mov x16, CHDIR
    adrp x0, workspace_1@PAGE
    add x0, x0, workspace_1@PAGEOFF
    svc SYSCALL

    b open_dir

select_entry:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    adrp x0, selected_entry@PAGE
    add x0, x0, selected_entry@PAGEOFF

    adrp x1, cur_entry@PAGE
    add x1, x1, cur_entry@PAGEOFF

    mov x27, #1024

clear_selected_entry:
    cbz x27, done_clearing_selected
    mov w13, #0
    strb w13, [x0], #1
    sub x27, x27, #1
    b clear_selected_entry

done_clearing_selected:
    adrp x0, selected_entry@PAGE
    add x0, x0, selected_entry@PAGEOFF

copy_cur_to_selected:
    ldrb w2, [x1]
    strb w2, [x0]

    cmp w2, #0
    beq open_dir

    add x0, x0, #1
    add x1, x1, #1

    b copy_cur_to_selected

remove_entry:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    ; reset entry_index
    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x1, [x0]

    mov x1, #0

    str x1, [x0]

    adrp x0, cur_entry_type@PAGE
    add x0, x0, cur_entry_type@PAGEOFF
    ldr x1, [x0]

    ; check if dir
    cmp x1, #DT_DIR
    beq remove_dir

    mov x16, UNLINK
    adrp x0, cur_entry@PAGE
    add x0, x0, cur_entry@PAGEOFF
    svc SYSCALL

    b open_dir

remove_dir:
    mov x16, RMDIR
    adrp x0, cur_entry@PAGE
    add x0, x0, cur_entry@PAGEOFF
    svc SYSCALL

    b open_dir

prompt_new_file_entry:
    mov x3, #1

    b set_termios_old

prompt_new_dir_entry:
    mov x3, #2

    b set_termios_old

prompt_new_symlink_entry:
    mov x3, #3

    b set_termios_old

prompt_copy_entry:
    mov x3, #4

    b set_termios_old

prompt_move_entry:
    mov x3, #5

    b set_termios_old

new_file_entry:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    ; reset entry_index
    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x1, [x0]

    mov x1, #0

    str x1, [x0]

    ; input has a newline at the end, remove it
    adrp x0, input@PAGE
    add x0, x0, input@PAGEOFF
    mov w5, #0

    sub x4, x4, #1

    strb w5, [x0, x4]

    mov x16, OPEN
    adrp x0, input@PAGE
    add x0, x0, input@PAGEOFF
    mov x1, #513
    mov x2, #0644
    svc SYSCALL

    mov x19, x0

    mov x16, CLOSE
    mov x0, x19
    svc SYSCALL

    b set_termios

new_dir_entry:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    ; reset entry_index
    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x1, [x0]

    mov x1, #0

    str x1, [x0]

    ; input has a newline at the end, remove it
    adrp x0, input@PAGE
    add x0, x0, input@PAGEOFF
    mov w5, #0

    sub x4, x4, #1

    strb w5, [x0, x4]

    mov x16, MKDIR
    adrp x0, input@PAGE
    add x0, x0, input@PAGEOFF
    mov x1, #0755
    svc SYSCALL

    b set_termios

new_symlink_entry:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    ; reset entry_index
    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x1, [x0]

    mov x1, #0

    str x1, [x0]

    ; input has a newline at the end, remove it
    adrp x0, input@PAGE
    add x0, x0, input@PAGEOFF
    mov w5, #0

    sub x4, x4, #1

    strb w5, [x0, x4]

    mov x16, SYMLINK
    adrp x0, selected_entry@PAGE
    add x0, x0, selected_entry@PAGEOFF
    adrp x1, input@PAGE
    add x1, x1, input@PAGEOFF
    svc SYSCALL

    b set_termios

copy_entry:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    ; reset entry_index
    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x1, [x0]

    mov x1, #0

    str x1, [x0]

    ; input has a newline at the end, remove it
    adrp x0, input@PAGE
    add x0, x0, input@PAGEOFF
    mov w5, #0

    sub x4, x4, #1

    strb w5, [x0, x4]

    ; get permissions of selected_entry
    sub sp, sp, #144
    mov x20, sp

    mov x16, STAT
    adrp x0, selected_entry@PAGE
    add x0, x0, selected_entry@PAGEOFF
    mov x1, x20
    svc SYSCALL

    ldrh w8, [x20, #8]
    and w9, w8, #0777

    ; open selected entry
    mov x16, OPEN
    adrp x0, selected_entry@PAGE
    add x0, x0, selected_entry@PAGEOFF
    mov x1, #0
    mov x2, #0
    svc SYSCALL

    mov x19, x0

    ; open copied entry
    mov x16, OPEN
    adrp x0, input@PAGE
    add x0, x0, input@PAGEOFF
    mov x1, #513
    mov x2, x9
    svc SYSCALL

    mov x20, x0

copy_file:

    sub sp, sp, #4095
    mov x21, sp

    ; read selected entry
    mov x16, READ
    mov x0, x19
    mov x1, x21
    mov x2, #4095
    svc SYSCALL

    mov x22, x0

    ; write to file
    mov x16, WRITE
    mov x0, x20
    mov x1, x21
    mov x2, x22
    svc SYSCALL

    cmp x22, #0
    bgt copy_file
   
close_copy_files:
    mov x16, CLOSE
    mov x0, x19
    svc SYSCALL

    mov x16, CLOSE
    mov x0, x20
    svc SYSCALL

    cmp x3, #5
    beq delete_copied_file

    b set_termios

delete_copied_file:

    mov x16, UNLINK
    adrp x0, selected_entry@PAGE
    add x0, x0, selected_entry@PAGEOFF
    svc SYSCALL

    b set_termios

edit_entry:
    mov x16, FORK
    svc SYSCALL

    mov x20, x0

    mov x16, GETPID
    svc SYSCALL

    cmp x20, x0
    beq forked_editor

    sub sp, sp, #16
    mov x21, sp

    mov x16, WAIT4
    mov x0, x20
    mov x1, x21
    mov x2, #0
    mov x3, xzr
    svc SYSCALL

    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    b open_dir
   
forked_editor:

    ; show cursor
    mov x16, WRITE
    mov x0, #1
    adrp x1, show_cursor@PAGE
    add x1, x1, show_cursor@PAGEOFF
    ldr x2, =6
    svc SYSCALL

    sub sp, sp, #24
    mov x5, sp

    adrp x4, text_editor_name@PAGE
    add x4, x4, text_editor_name@PAGEOFF
    str x4, [x5, #0]

    adrp x4, cur_entry@PAGE
    add x4, x4, cur_entry@PAGEOFF
    str x4, [x5, #8]

    str xzr, [x5, #16]

    mov x16, EXECVE
    adrp x0, text_editor_path@PAGE
    add x0, x0, text_editor_path@PAGEOFF
    mov x1, x5
    mov x2, xzr
    svc SYSCALL

    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    b exit


jump_to_first:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x1, [x0]

    mov x1, #0

    str x1, [x0]

    b open_dir

jump_to_last:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x1, [x0]

    mov x1, x25

    str x1, [x0]

    b open_dir
    
set_next_dir:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    ; reset entry_index
    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x1, [x0]

    mov x1, #0

    str x1, [x0]

    mov x16, CHDIR
    adrp x0, cur_entry@PAGE
    add x0, x0, cur_entry@PAGEOFF
    svc SYSCALL

    adrp x0, cur_workspace@PAGE
    add x0, x0, cur_workspace@PAGEOFF
    ldr x1, [x0]

    cmp x1, #0
    beq clear_workspace_1

    cmp x1, #1
    beq clear_workspace_2

    b open_dir

set_prev_dir:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    ; reset entry_index
    adrp x0, entry_index@PAGE
    add x0, x0, entry_index@PAGEOFF
    ldr x1, [x0]

    mov x1, #0

    str x1, [x0]

    mov x16, CHDIR
    adrp x0, last_dir@PAGE
    add x0, x0, last_dir@PAGEOFF
    svc SYSCALL

    adrp x0, cur_workspace@PAGE
    add x0, x0, cur_workspace@PAGEOFF
    ldr x1, [x0]

    cmp x1, #0
    beq clear_workspace_1

    cmp x1, #1
    beq clear_workspace_2

    b open_dir

exit:
    ; clear
    mov x16, WRITE
    mov x0, #1
    adrp x1, clear@PAGE
    add x1, x1, clear@PAGEOFF
    ldr x2, =10
    svc SYSCALL

    ; show cursor
    mov x16, WRITE
    mov x0, #1
    adrp x1, show_cursor@PAGE
    add x1, x1, show_cursor@PAGEOFF
    ldr x2, =6
    svc SYSCALL

    ; exit
    mov x16, EXIT
    mov x0, #0
    svc SYSCALL

.data
    entry_index:        .dword 0
    cur_workspace:      .dword 0

    newline:            .asciz "\n\033[0m"

    clear:              .asciz "\033[1;1H\033[2J"

    hide_cursor:        .asciz "\033[?25l"
    show_cursor:        .asciz "\033[?25h"

    dir_color:          .asciz "\033[1;32m "
    link_color:         .asciz "\033[0;34m "
    highlight_cur:      .asciz "\033[47m"
    highlight_selected: .asciz "\033[46m"

    text_editor_name:   .asciz "vim"
    text_editor_path:   .asciz "/usr/bin/vim"

    cwd:                .asciz "."
    last_dir:           .asciz ".."

.bss
    workspace_0:        .space 1024
    workspace_1:        .space 1024

    input:              .space 1024

    cur_entry:          .space 1024
    cur_entry_type:     .space 16

    selected_entry:     .space 1024

    termios:            .space TERMIOS_SIZE
    termios_new:        .space TERMIOS_SIZE