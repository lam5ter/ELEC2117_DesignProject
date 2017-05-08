
	list	p=16f886	; list directive to define processor
	#include	<p16f886.inc>	; processor specific variable definitions


;***** VARIABLE DEFINITIONS

store	EQU	0x20
count	EQU	0x21

key0	EQU	0x22
key1	EQU	0x23
key2	EQU	0x24
key3	EQU	0x25
key4	EQU	0x26
key5	EQU	0x27
key6	EQU	0x28
key7	EQU	0x29
key8	EQU	0x2A
key9	EQU	0x2B
key10	EQU	0x2C
key11	EQU	0x2D
key12	EQU	0x2E
key13	EQU	0x2F
key14	EQU	0x30
key15	EQU	0x31

;temp	EQU	0x38

;**********************************************************************
	ORG	0x000	; processor reset vector

	nop
  	goto	main	; go to beginning of program


main 	
	BANKSEL	ANSEL
	clrf	ANSEL
	BANKSEL	TRISA
	movlw	B'00001111'
	movwf	TRISA
	clrf	TRISC
	BANKSEL	PORTA
	clrf	PORTA
	clrf	PORTC

	;set up jump table
	movlw	H'01'
	movwf	key0
	movlw	H'02'
	movwf	key1
	movlw	H'03'
	movwf	key2
	movlw	H'0F'
	movwf	key3
	movlw	H'04'
	movwf	key4
	movlw	H'05'
	movwf	key5
	movlw	H'06'
	movwf	key6
	movlw	H'0E'
	movwf	key7
	movlw	H'07'
	movwf	key8
	movlw	H'08'
	movwf	key9
	movlw	H'09'
	movwf	key10
	movlw	H'0D'
	movwf	key11
	movlw	H'0A'
	movwf	key12
	clrf	key13
	movlw	H'0B'
	movwf	key14
	movlw	H'0C'
	movwf	key15

keyscan
	movlw	B'01111111'
	movwf	store
	movlw	D'4'
	movwf	count
rowscan
	;move to position in jump-table
	movlw	H'22'
	btfss	store,5
	addlw	H'04'
	btfss	store,6
	addlw	H'08'
	btfss	store,7
	addlw	H'0C'
	movwf	FSR

	;check if key in row has been pressed
	movf	store,0
	movwf	PORTA
	movf	PORTA,0
	nop
	xorwf	store,0
;	movwf	temp
	btfss	STATUS,2

	;call display function here
	call	led_display

	;reset and move to second row
	bcf	STATUS,2
	bsf	STATUS,0
	rrf	store,1
	decfsz	count,1
	goto	rowscan

	;reset and begin scan again
	goto	keyscan

led_display
	clrw
	btfss	PORTA,1
	movlw	D'1'
	btfss	PORTA,2
	movlw	D'2'
	btfss	PORTA,3
	movlw	D'3'
	addwf	FSR,1

	movf	INDF,0
	movwf	PORTC

	return

	END	; directive 'end of program'


