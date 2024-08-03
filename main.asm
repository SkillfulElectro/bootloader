  bits 16
  ;; real mode 16bits

  ;; ax is general purpose reg
  ;; we have set ds (data segment reg) to this value but
  ;; its not possible to set that reg directly so we have to 
  ;; use general purpose registers for it
  mov ax , 0x7C0
  ;; BIOS looks for first sector of our drive , and if it contains bootloader code
  ;; it will load it to 0x007C00 address so why we set ds to 0x7C0h?
  ;;   because in x86 real mode , we must use addresses in 16bit format ! 
  ;;     so dividing 0x007C00 by 16 (shifting to right by 4) results in 0x7C0
  ;;     h at the end tells that this is hexadecimal
  ;      you can use h or 0x for that not both with nasm
  mov ds , ax

  ;; ss = stack segment 
  ;; here we define the base address of starting point of our stack
  mov ax , 0x7E0
  mov ss , ax

  ;; sp = stack pointer
  ;; we set it to end of our stack
  mov sp , 0x2000


  call clearscreen
  ; calling the clearscreen function
  ; -> new stack frame is created now for the function
  ; -> bp reg is set to stack frame of caller

  ; pushing 0000h to the stack
  push 0000h
	call movecursor
  ; freeing the two bytes we pushed to the stack
	add sp, 2

	push msg
	call print
	add sp, 2

  ; By executing cli, you disable interrupts, which means that the CPU will not respond to external interrupt requests.
	cli
	hlt

clearscreen:
  ; bp = base pointer
  ; saving the prev bp which is now pointing to the caller's stack frame
  ; sp decreased by 2 
  push bp

  ; now we set up new bp , so this way bp points to the 
  ; top of the stack
  mov bp, sp

  ; pushing value of all general purpose registers to the stack
  pusha
  ; this is done to restore the prev value of them with calling popa
  ; after the function finished

  
  mov ah, 0x07        ; tells BIOS to scroll down window
  mov al, 0x00        ; clear entire window
  mov bh, 0x07            ; white on black
  mov cx, 0x00        ; specifies top left of screen as (0,0)
  mov dh, 0x18        ; 18h = 24 rows of chars
  mov dl, 0x4f         ; 4fh = 79 cols of chars
  int 0x10        ; calls video interrupt 
  ; now video interrupt does everything based on values of those registers

  ; now popa restores values of registers from before
  popa

  ; now we set sp to starting of our function stack frame
  ;   so when we use pop , top of the sp gives us caller's 
  ;   stack frame
  mov sp, bp

  ; now we pop address of stack frame of the function
  pop bp

  ; here ret calls pop , and it returns an address which is stack frame of the caller
  ; and jumps to it
  ret

movecursor:
  ; here the same thing as clearscreen happens
	push bp
	mov bp, sp
	pusha

  ; each value which is pushed to the stack will occupy 2 bytes (16 bits) because 
  ; cpu is operating on real mode , so if we come back two bytes we will reach to 
  ; caller's stack frame address and another two bytes to reach to what we pushed 
  ; to the stack before calling the function
	mov dx, [bp+4] ; get the argument from the stack. |bp| = 2, |arg| = 2
	mov ah, 02h ; set cursor position
	mov bh, 00h  ; page 0 - doesn't matter, we're not using double-buffering
	int 10h  ; invoke BIOS video interrupt to move cursor to specified position

  ; here is the same thing
	popa
	mov sp, bp
	pop bp
	ret

print:
  ; same as before
	push bp
	mov bp, sp
	pusha


	mov si, [bp+4]  ; grab the pointer to the data
	mov bh, 00h         ; page number, 0 again
	mov bl, 00h ; foreground color, irrelevant - in text mode
	mov ah, 0Eh  ; print character to TTY

  ; loop for printing chars
 .char:
	mov al, [si]   ; get the current char from our pointer position
	add si, 1 ; keep incrementing si until we see a null char

  ; or instruction does bitwise OR operation
  ; When you perform a logical OR operation with the instruction or al, 0, 
  ; you are effectively testing the value of the al register to see if it is zero.
	or al, 0
  ; or al, 0 checks if al is zero. If al is 0x00 (null terminator), it indicates the end of the string.
  ; The instruction or al, 0 performs a bitwise OR operation between the al register and 0. 
  ; This operation doesn't change the value in al, but it affects the processor’s status flags:
  ; Zero Flag (ZF): This flag is set to 1 if the result of the OR operation is 0. If al is 0, ZF will be set to 1
  ; otherwise, it will be cleared (set to 0).

  ; jumps if zf is set , jne is jumps if zf is not set
	je .return        ; end if the string is done
	int 10h         ; print the character if we're not done
	jmp .char  ; keep looping

 .return:

  ; same as before
	popa
	mov sp, bp
	pop bp
	ret

; db = define byte , used to allocate memory to init
; define the null-terminated string to print
msg: db "Oh boy do I sure love assembly!", 0

  ; pad the bootloader to 510 bytes with zeros
	times 510-($-$$) db 0
	dw 0xAA55 ; this line tells to BIOS that this 512 byte is bootloader code
