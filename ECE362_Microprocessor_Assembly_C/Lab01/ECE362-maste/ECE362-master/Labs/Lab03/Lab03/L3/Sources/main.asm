;***********************************************************************
; ECE 362 - Experiment 3 - Fall 2012
;***********************************************************************
;
; Completed by: < your name >
;               < your class number >
;               < your lab division >
;
;
; Academic Honesty Statement:  In signing this statement, I hereby certify
; that I am the individual who created this HC12 source file and that I have
; not copied the work of any other student (past or present) while completing it.
; I understand that if I fail to honor this agreement, I will receive a grade of
; ZERO and be subject to possible disciplinary action.
;
;
; Signature: ________________________________________________   Date: ____________
;
; NOTE: The printed hard copy of this file you submit for evaluation must be signed
;       in order to receive credit.
;

;***********************************************************************
; Character I/O Library Routines for 9S12C32
;***********************************************************************
;
; ==== SCI Register Definitions

SCIBDH		equ	$00C8		;SCI0BDH - SCI BAUD RATE CONTROL REGISTER
SCIBDL		equ	$00C9		;SCI0BDL - SCI BAUD RATE CONTROL REGISTER
SCICR1		equ	$00CA		;SCI0CR1 - SCI CONTROL REGISTER
SCICR2		equ	$00CB		;SCI0CR2 - SCI CONTROL REGISTER
SCISR1		equ	$00CC		;SCI0SR1 - SCI STATUS REGISTER
SCISR2		equ	$00CD		;SCI0SR2 - SCI STATUS REGISTER
SCIDRH		equ	$00CE		;SCI0DRH - SCI DATA REGISTER
SCIDRL		equ	$00CF		;SCI0DRL - SCI DATA REGISTER
PORTB		  equ	$0001		;PORTB - DATA REGISTER
DDRB		  equ	$0003		;PORTB - DATA DIRECTION REGISTER

; ==== ASCII Character Definitions

NULL    	equ	$00
CR      	equ	$0D
LF      	equ	$0A

; ==== Specify initial debugger PC
                ABSENTRY nchars

;***********************************************************************
; Step 1: 
;
; Subroutine: nchars
;
; Inputs: ASCII value of starting character in the A register
;         Number of characters to be printed in the B register
;
; Function: Prints a series of N characters beginning with the ASCII 
;	          character in the A register and followed by the N-1 
;	          characters that follow in the ASCII table
;
; Subroutines called:  outchar
;
;***********************************************************************

      	org	$0800
      	LDS #$1000
      	jsr sinit
      	
nchars
        jsr outchar
        inca
        decb
        cmpb #0
        beq nchars_exit
        bra nchars
        
nchars_exit        

	      rts  ;return from sub

;***********************************************************************
; Step 2: 
; 
; Program: ncmain
;
; Function:  Prompts the user for the beginning character and the 
;            number of characters to be printed.
;            Prints a series of N characters beginning with the ASCII 
;	           character in the A register and followed by the N-1 
;	           characters that follow in the ASCII table (call nchars).
;	           Entering the character "q" should cause the program to exit.
;
; Subroutines called:  <List the subroutines you use here>
;
;***********************************************************************

      	org	$0850
ncmain 	lds	#$1000	; initialize SP
      	jsr	sinit 	; initialize serial port
         

char_prompt
        jsr pmsg
        fcb CR,LF
        fcb "Enter Character: ",NULL
             
         
                                       
        jsr inchar
        psha
        
        cmpa #$71     
        BEQ char_end
        
        jsr outchar
        pula

        exg a,b
        
        jsr pmsg
        fcb CR,LF
        fcb "Enter Number: ",NULL
        
        jsr inchar
        psha
        jsr outchar
        pula
        
        suba #$30

        exg a,b
        
        jsr pmsg
        fcb CR,LF,NULL
        
        
        jsr nchars
        

        BRA char_prompt
        
char_end       
        
      	stop		    ;breakpoint here
 

;***********************************************************************
; Step 3: 
;
; Subroutine: reverse
;
; Inputs: A string of up to 30 characters and stores them in the array, 
;         marray (declared for you).	
;
; Function: When the user has entered 30 characters or a carriage return,
;           defined above as CR, print the string in reverse order.
;
; Subroutines called:  ?????
;
;***********************************************************************

      	org	$0900
reverse lds	#$1000
      	jsr	sinit

        
        
while_start
        ldx #29
        ldy #0
while_loop

        cpx #0
        beq while_exit

        jsr inchar
        
        
        cmpa #CR
        BEQ while_exit
       
        jsr outchar
        
        
        staa marray, x
        
        iny
        dex
        
        bra while_loop
        
while_exit     
   
    pshx
    
    jsr pmsg
    fcb CR,LF,NULL
    
    pulx    
        
for_loop
        ;exg x,y
        
        ldaa marray,x
        
        jsr outchar
        
        inx
        
        cpx #30
        
        BHS exit
        bra for_loop
    
exit    

      	stop		    ;breakpoint here
      	            
marray	rmb	30      ; reserve 30 bytes for the marray


;***********************************************************************
; Step 4: 
;
; Subroutine: pmsgx
;
; Inputs: X register contains the starting address of a NULL-terminated
;	        string
;
; Function: Prints the string beginning with the address in the X 
;           register.
;
; Subroutines called:  ?????
;
;***********************************************************************
      	
      	org	$0A00 ;start address
pmsgx   psha

ploop2  ldaa    1,x+    ; Get next character of string.
        beq     pexit2   ; Exit if ASCII null encountered.
        jsr     outchar ; Print character on terminal screen.
        bra     ploop2   ; Process next string character.
pexit2  pula
                    ; Place corrected return address on stack.
        rts             ; Exit routine

      	rts       ;return from sub

;***********************************************************************
; Step 5: 
;
; Program: message
;
; Defined value:  N, which is the number of regular messages allowed. 
;    (In addition, there is an "exit" message and an error message.)
;
; Function:  Prompts the user for a message number, prints the
;	           corresponding message, then repeats the prompt.
;            The program provides an error message if the
;            message number is out-of-range.  If the user selects 0,
;            the program will print an exit message and exit.
;
;	           (also answers the question, "Were you awake in class??")
;
; Subroutines called:  pmsgx and ?????
;
;***********************************************************************

N    	  equ	$04   ;number of messages

      	org	$0A50 	;start address
message
	      lds	#$1000
	      jsr	sinit
        ldx #msgtbl
        
      
        
while_loop2
       
        jsr pmsg 
        
        fcb "Enter Message Number (0-4)"
        fcb CR, LF, NULL
        
        jsr inchar
        psha
        jsr outchar
        pula
        
        jsr pmsg
        fcb CR, LF, NULL
        
        suba #$30
        
        jsr case0
        
        bra while_loop2
        
        
while_exit2        

	      stop ;breakpoint here
	      

case0
        cmpa #0
        bne case1
        
        
        ldx #msg0
        jsr pmsgx

        bra while_exit2
case1
        cmpa #1
        bne case2
        
        ldx #msg1
        jsr pmsgx
        
        bra while_loop2       
case2
        cmpa #2
        bne case3
        
        ldx #msg2
        jsr pmsgx
        
        bra while_loop2        
case3
        cmpa #3
        bne case4
        
        ldx #msg3
        jsr pmsgx
        
        bra while_loop2
case4
        cmpa #4
        bne default
        
        ldx #msg4
        jsr pmsgx
        
        bra while_loop2                

default
        
        
        ldx #xmsg
        jsr pmsgx
        
        bra while_loop2



;
; This table contains the addresses of the messages 0 - N
;

msgtbl	fdb	msg0     ;fdb = form double byte (16-bits)
	      fdb	msg1
	      fdb	msg2
	      fdb	msg3
	      fdb	msg4

;
; Message storage area
;

msg0  	fcc	"Good-bye!"
      	fcb	CR,LF,NULL
msg1  	fcc	"Message 1."
      	fcb	CR,LF,NULL
msg2  	fcc	"Message 2."
      	fcb	CR,LF,NULL
msg3  	fcc	"Message 3."
	      fcb	CR,LF,NULL
msg4  	fcc	"Message 4."	
      	fcb	CR,LF,NULL
xmsg  	fcc	"Invalid message number.  Try again!"
      	fcb	CR,LF,NULL



;***********************************************************************
; Step 6: 
;
; Program: evmain
;
; Inputs: None
;
; Function: 1) Prompts the user to enter the two operands and the function to 
;              be performed, and stores these items on the stack
; 	        2) Calls eval to evaluation the expression on the stack
;	          3) Pops the result from the stack and prints the result
;
; Subroutines called:  ??
;
;***********************************************************************

	      org	$0C00
evmain  lds	#$1000
	      jsr	sinit

        jsr pmsg 
        fcb CR, LF
        fcb "Op 1: ", NULL
        
        jsr inchar
        jsr outchar
        suba #$30
        psha
                     
                     
        jsr pmsg 
        fcb CR, LF
        fcb "Op 2: ", NULL
        
        jsr inchar
        jsr outchar
        suba #$30
        psha
      
        
        jsr pmsg 
        fcb CR, LF
        fcb "Function: ", NULL
        
        jsr inchar
        jsr outchar
         psha
        
        
        jsr eval
        

        jsr pmsg 
        fcb CR, LF
        fcb "Result: ", NULL
        pula
        jsr pmsg

	      stop		;breakpoint here

eval_sp rmb 2

;***********************************************************************
;
; Program: eval
; 
; Input: The expression, in: function, operand 2, operand 1 order, is
;        located on the stack (note the return address is at top of stack)
;
; Function: Evaluate the expression, then store the result back on the
;        stack.  Note: the expression is defined as Op1 Function Op2.
;        Only the CCR is modified (all other registers remain unmodified)
;
; Subroutines called:  ?????
;
;***********************************************************************

        org $0D00
eval
        puld
        std eval_sp
        
        ldd #$0000
        ldy #$00
        
        pula  ;FUNCTION
        ;puly  ;op1
        ;pulb  ;op2
       
caseA
        cmpa #$41 ;A, add y+b
        bne caseS
        
        pula ;op1
        pulb ;op2
        
        aba
        
        bra eval_end

caseS
        cmpa #$53    ;S, subtract y-b 
        bne caseM
        
        exg y,b
        subb y
        exg y,b
        
        bra eval_end
      
caseM
        cmpa #$4d    ;M, multiply y*b
        bne caseX
        
        exg A,Y
        mul
        
        bra eval_end
        
caseX
        cmpa #$58    ;X, xor y (eorb)b 
        bne eval_end
        
        eorb y
        
        bra eval_end      
        
        
eval_end
       
        exg y,b
        std eval_sp
        pshd
        pshy
        
	      rts	;return from sub


;***********************************************************************
; Character I/O Library Routines for 9S12C32
;***********************************************************************
;
; Initialize asynchronous serial port (SCI) for 9600 baud
;
; Assumes PLL not engaged -> CPU bus clock is 4 MHz
;

sinit	  movb	#$00,SCIBDH	; set baud rate to 9600
	      movb	#$1A,SCIBDL	; 4,000,000 / 16 / 26 = 9600 (approx)
	      movb	#$00,SCICR1	; $1A = 26
	      movb	#$0C,SCICR2	; initialize SCI for program-driven operation
	      movb	#$10,DDRB	; set PB4 for output mode
	      movb	#$10,PORTB	; assert DTR pin of COM port
	      rts

;
; SCI handshaking status bits
;

rxdrf   equ   $20    ; receive data register full (RDRF) mask pattern
txdre   equ   $80    ; transmit data register empty (TDRE) mask pattern

;***********************************************************************
; Name:         inchar
; Description:  inputs ASCII character from SCI serial port
;                  and returns it in the A register
; Returns:      ASCII character in A register
; Modifies:     A register
;***********************************************************************

inchar  brclr  SCISR1,rxdrf,inchar
        ldaa   SCIDRL ; return ASCII character in A register
        rts

;***********************************************************************
; Name:         outchar
; Description:  outputs ASCII character passed in the A register
;                  to the SCI serial port
;***********************************************************************

outchar brclr  SCISR1,txdre,outchar
        staa   SCIDRL ; output ASCII character to SCI
        rts

;***********************************************************************
; pmsg -- Print string following call to routine.  Note that subroutine
;         return address points to string, and is adjusted to point to
;         next valid instruction after call as string is printed.
;***********************************************************************

pmsg    pulx            ; Get pointer to string (return addr).
        psha
ploop   ldaa    1,x+    ; Get next character of string.
        beq     pexit   ; Exit if ASCII null encountered.
        jsr     outchar ; Print character on terminal screen.
        bra     ploop   ; Process next string character.
pexit   pula
        pshx            ; Place corrected return address on stack.
        rts             ; Exit routine.
	
;***********************************************************************
; Subroutine:	htoa
; Description:  converts the hex nibble in the A register to ASCII
; Input:	hex nibble in the A accumualtor
; Output:	ASCII character equivalent of hex nibble
; Reg. Mod.:	A, CC
;***********************************************************************

htoa	  adda	 #$90
	      daa
	      adca	 #$40
	      daa
	      rts

;***********************************************************************
; ECE 362 - Experiment 3 - Fall 2012
;***********************************************************************
