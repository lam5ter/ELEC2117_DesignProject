
	list	p=16f886	; list directive to define processor
	#include	<p16f886.inc>	; processor specific variable definitions


;***** VARIABLE DEFINITIONS


counter0	EQU	0x20	;Delay counter
counter1	EQU	0x21	;Delay counter
transfer_c	EQU	0x22	;Counter for transfers
fm_address	EQU	0x23	;Address of FM Radio and bit 0 sets R/W
start_ADD	EQU	0x24	;Start address for data transfer

	
	cblock	0x30
		DEVICEID_H
		DEVICEID_L
		CHIPID_H
		CHIPID_L
		POWERCFG_H	;Write starts here
		POWERCFG_L
		CHANNEL_H
		CHANNEL_L
		SYSCONFIG1_H
		SYSCONFIG1_L
		SYSCONFIG2_H
		SYSCONFIG2_L
		SYSCONFIG3_H
		SYSCONFIG3_L
		TEST1_H
		TEST1_L
		TEST2_H
		TEST2_L
		BOOTCONFIG_H
		BOOTCONFIG_L
		STATUSRSSI_H	;Read starts here
		STATUSRSSI_L
		READCHAN_H
		READCHAN_L
		RDSA_H
		RDSA_L
		RDSB_H
		RDSB_L
		RDSC_H
		RDSC_L
		RDSD_H
		RDSD_L
	endc
	

;**********************************************************************
	ORG	0x000	; processor reset vector

	nop
  	goto	main	; go to beginning of program


main 	
	BANKSEL	ANSEL
	clrf	ANSEL
	BANKSEL	TRISC
	movlw	B'00011000'	;RC3 and RC4 set to output
			;RC2 is RST, RC1 is SEN
	movwf	TRISC
	BANKSEL	OPTION_REG
	movlw	B'00000100'	;prescaler of 32
	movwf	OPTION_REG
	BANKSEL	SSPSTAT
	movlw	B'10000000'
	movwf	SSPSTAT
	BANKSEL	SSPCON
	movlw	B'00101000'
	movwf	SSPCON
	BANKSEL	SSPADD
	movlw	D'9'	;just because
	movwf	SSPADD

;-------------------------------------------------------------
;Initialising FM Radio

	BANKSEL	PORTC
	bcf	PORTC,2	;Clear RST
	bcf	PORTC,1	;Clear SEN
			;Can just pull SEN to GND
	call	delay5ms
	bsf	PORTC,2	;Set RST

	call	delay1s

	;Powerup Mode
	movlw	B'01000000'
	movwf	POWERCFG_H
	movlw	B'00000001'
	movwf	POWERCFG_L

	movlw	D'2'
	movwf	transfer_c
	call	radio_write

	call	radio_read	;Check data set on the FM-Tuner


;Adjusting for Australian channels
;87.5 with 0.2 spacing
	;Set SEEKTH to 0x19 -> 00010011
	bsf	SYSCONFIG2_H,4
	bsf	SYSCONFIG2_H,1
	bsf	SYSCONFIG2_H,0

	;Set SKSNR to 0x4 -> 0100
	bsf	SYSCONFIG3_L,6

	;Set SKCNT to 0x8 -> 1000
	bsf	SYSCONFIG3_L,3



;Set volume to 0 dBFS -> 1111
	bsf	SYSCONFIG2_L,3
	bsf	SYSCONFIG2_L,2
	bsf	SYSCONFIG2_L,1
	bsf	SYSCONFIG2_L,0
	
;Tune to freq 96.9
	movlw	B'00101111'	;D'47'
	movwf	CHANNEL_L

	movlw	D'10'
	movwf	transfer_c
	call	radio_write

;Tune to a single channel
	bsf	CHANNEL_H,7	;Enable TUNE

	movlw	D'10'
	movwf	transfer_c
	call	radio_write

	call	delay60ms
	call	radio_read

default_tune
	btfss	STATUSRSSI_H,6
	goto	default_tune	;Check if tune was successful
		
	bcf	CHANNEL_H,7	;Enable TUNE

	movlw	D'10'
	movwf	transfer_c
	call	radio_write
	call	radio_read

;Finish operations
main_loop	
	goto	main_loop
	

;-------------------------------------------------------------
;Data transfer between PIC and FM Radio

;Write data to the FM-Tuner
radio_write
	BANKSEL	SSPCON2
	bcf	SSPCON2,3	;Set to transmit mode
	BANKSEL	SSPBUF
	movlw	B'00100000'
	movwf	fm_address	;Send address and set FM radio to write
	movlw	H'34'	;Start address for write
	movwf	start_ADD
multi_write
	call	i2cStart
	movlw	H'23'
	movwf	FSR	;FM-Tuner address
	call	i2cWrite
	movf	start_ADD
	movwf	FSR
write_loop
	call	i2cWrite
	incf	FSR
	decfsz	transfer_c,1	;Writes specified number of times
	goto	write_loop
	call	i2cStop
	return


;Read data from the radio registers
radio_read
	movlw	B'00100001'
	movwf	fm_address	;Send address and set FM radio to read
	movlw	D'12'
	movwf	transfer_c	;Number of transfers
	movlw	H'44'	;Start address for read
	movwf	start_ADD
	call	i2cStart

	movlw	H'23'
	movwf	FSR
	call	i2cWrite	;FM-radio address

	call	i2cRead	;Read addresses from H'0A' to H'0F'

	;Loop back to start addresses
	movlw	H'30'
	movwf	start_ADD
	movlw	D'20'
	movwf	transfer_c
	call	i2cRead	;Read addresses from H'00' to H'09'
	call	i2cWait
	call	i2cNCK
	call	i2cStop

	return


;-------------------------------------------------------------
;I2C Function Controls

;Start signal	
i2cStart
	BANKSEL	SSPCON2
	bsf	SSPCON2,0	;enable SEN
wait_start
	btfsc	SSPCON2,0
	goto	wait_start
	BANKSEL	SSPBUF
	return	


;Send stop signal
i2cStop
	BANKSEL	SSPCON2
	bsf	SSPCON2,2	;enable PEN
wait_stop
	btfsc	SSPCON2,2
	goto	wait_stop
	BANKSEL	SSPBUF
	return


;Send restart signal
i2cRestart
	BANKSEL	SSPCON2
	bsf	SSPCON2,1	;enable RSEN
wait_restart
	btfsc	SSPCON2,1
	goto	wait_restart
	BANKSEL	SSPBUF
	return


;Transmit an ACK to slave (during a read)
i2cACKEN
	BANKSEL	SSPCON2
	bcf	SSPCON2,5	;clear ACKDT
	bsf	SSPCON2,4	;set ACKEN to send ACK
wait_T_Ack
	btfsc	SSPCON2,4
	goto	wait_T_Ack
	return


;Wait to receive an ACK from a slave
i2cACKSTAT
	BANKSEL	SSPCON2
wait_R_Ack
	btfsc	SSPCON2,6	
	goto	wait_R_Ack
	BANKSEL	SSPBUF
	return


;Send a NCK to a slave (to stop further data transfer
i2cNCK
	BANKSEL	SSPCON2
	bsf	SSPCON2,5	;set ACKDT
	bsf	SSPCON2,4	;set ACKEN to send NCK
wait_nak
	btfsc	SSPCON2,4
	goto	wait_nak
	BANKSEL	SSPBUF
	return


;Wait for any data to finish transmission
i2cWait
	BANKSEL	SSPSTAT
wait_transmit
	btfsc	SSPSTAT,0	;Check if there is still any data transfer
	goto	wait_transmit
	BANKSEL	SSPBUF
	return


;Load values from the PIC register to FM Radio
i2cWrite
	movf	INDF,0
	movwf	SSPBUF
	call	i2cWait
	call	i2cACKSTAT
	return


;Read and save values from FM radio to PIC registers
i2cRead
	BANKSEL	SSPCON2
	bsf	SSPCON2,3	;Set RCEN to enable receive mode
	BANKSEL	SSPBUF
	movf	start_ADD	;First register to read into
	movwf	FSR
read_data
	call	i2cACKEN	;Transmit ACK to receive next data
	BANKSEL	SSPCON2
wait_receive
	btfsc	SSPCON2,3	;When cleared, data has filled SSPBUF
	goto	wait_receive

	bsf	SSPCON2,3	;Reset RCEN to prepare for next instruction
	call	i2cACKEN	;Transmit ACK to receive next data
	BANKSEL	SSPBUF
	movf	SSPBUF,0
	movwf	INDF	;Write data to shadow register
	incf	FSR	;Increment to next shadow register
	decfsz	transfer_c,1
	goto	read_data

	return
	
			

;---------------------------------------------
;Delays

delay1s
	movlw	D'200'
	movwf	counter1
loop_1s
	call	delay5ms
	decfsz	counter1,1
	goto	loop_1s
	return


delay60ms	;60ms delay routine
	movlw	D'60'
	movwf	counter0
loop_60ms
	call	delay1ms
	decfsz	counter0,1
	goto	loop_60ms
	return


delay5ms	;5ms delay routine
	movlw	D'5'
	movwf	counter0
loop_5ms
	call	delay1ms
	decfsz	counter0,1
	goto	loop_5ms
	return	


delay1ms	;1ms delay routine
	bcf	INTCON,2
	movlw	D'225'
	movwf	TMR0	;count to 31
loop_ms
	btfss	INTCON,2
	goto	loop_ms
	bcf	INTCON,2
	return


	END	; directive 'end of program'