;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ＩＰＬセレクタメーカー for MZ-80K/C・1200
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  作成：菅　秀樹
;;  履歴：Ver 0.1 2020年12月12日 初回リリース
;;        Ver 0.2 2020年12月12日 IPLSのVerUPによる
;;        Ver 0.3 2021年02月22日 IPLSのVerUPとアセンブラ変更
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  モニタ&FD-IF ROM内ルーチン等
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
RESET	EQU	00000H	; リセット
GETL	EQU	00003H	; 1ライン入力
LETNL	EQU	00006H	; [CR]の実行
NEWLIN	EQU	00009H	; ニューライン
MSG	EQU	00015H	; メッセージ表示
LIST	EQU	00018H	; リスト用メッセージ表示
MELDY	EQU	00030H	; 音楽演奏の実行
BELL	EQU	0003EH	; BEEP音
XTEMP	EQU	00041H	; テンポセット
ST1	EQU	00082H	; モニタに戻る

PRTWRD	EQU	003BAH	; 16進2バイトHEX表示(HL)
PRTBYT	EQU	003C3H	; 16進1バイトHEX表示(A)

NNF8	EQU	01001H	; 0nnF8Hのnn
L1000	EQU	01000H	; ポート0FAHの出力内容
M_RTRY	EQU	01007H	; リトライ用カウンタ
E_HOOK	EQU	0100BH	; エラーフック
BTDRV	EQU	01011H	; 起動ドライブ番号
DSPX	EQU	01171H	; カーソルX座標
F_DMON	EQU	0F090H	; ドライブ モータ オン
F_DMOFF	EQU	0F0A7H	; ドライブ モータ オフ
F_SZERO	EQU	0F0B2H	; シーク ゼロ
F_READY	EQU	0F0BDH	; FDCがREADYになるまで待つ
F_ST	EQU	0F0D9H	; FDCステータス
F_REMD	EQU	0F0FFH	; PRMドライブ (ドライブの起動)
F_LOAD	EQU	0F13BH	; FD読込

F_WAIT1	EQU	0F1A6H	; wait

IOF8	EQU	0F8H	; SES
IOF9	EQU	0F9H	; FDC
IOFA	EQU	0FAH	; SME
IOFB	EQU	0FBH	; PRM



;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  メイン
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	ORG	01200H

START:

	LD	A,00AH		; リトライ用カウンタ　セット
	LD	(M_RTRY),A
;
	LD	A,0C3H		; エラーフック設定
	LD	(E_HOOK),A
	LD	HL,ER_HOOK
	LD	(E_HOOK + 1),HL

	CALL	F_DMOFF		; ドライブ モータ オフ
;
; オープニング メッセージ表示
	CALL	LETNL		; 改行
	CALL	LETNL		; 改行
	LD	DE,OPMSG1	; OP1
	CALL	MSG
	CALL	LETNL		; 改行
	CALL	LETNL		; 改行
;
;   ターゲットのドライブ番号入力
DSEL:
	LD	DE,OPMSG2	; OP1
	CALL	MSG
	CALL	LETNL		; 改行

PSEL:
	LD	DE,SELMSG	; セレクトメッセージ表示
	CALL	MSG

	LD	DE,SELWK
	CALL	GETL		; 1ライン入力
	LD	HL,SELMSGE - SELMSG - 1	; 入力値格納 オフセット
	ADD	HL,DE		; 入力値格納アドレス
	LD	A,(HL)		; A<-入力値

	CP	'!'
	JP	Z,ST1		; モニタに戻る

	SUB	'1'		; '1'～'4' -> 0～3
	JR	C,PSEL		; 1未満?

	LD	(BTDRV),A	; TARGETセレクト保存

	CP	4
	JR	NC,PSEL		; 4より大きい?


;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BOOT、SP-6110ディスク判定 トラック：0 セクタ:1読込
	LD	A,(BTDRV)	; TARGETセレクト
	LD	(P_DIR),A	; ドライブ
	XOR	A
	LD	(P_TRK),A	; トラック0
	INC	A
	LD	(P_SEC),A	; セクタ1
	LD	HL,128		; 読込サイズ
	LD	(P_SIZ),HL
	LD	HL,DIR1		; ロードアドレス
	LD	(P_ADR),HL

	LD	IX,P_DIR
	CALL	F_LOAD		; FD読込

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BOOT、SP-6110ディスク判定 トラック：1 セクタ:1読込
	LD	A,(BTDRV)	; TARGETセレクト
	LD	(P_DIR),A	; ドライブ
	XOR	A
	INC	A
	LD	(P_TRK),A	; トラック1
	LD	(P_SEC),A	; セクタ1
	LD	HL,128		; 読込サイズ
	LD	(P_SIZ),HL
	LD	HL,DIR2		; ロードアドレス
	LD	(P_ADR),HL

	LD	IX,P_DIR
	CALL	F_LOAD		; FD読込

	CALL	F_DMOFF		; ドライブ モータ オフ

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SP-6110 のディスクは対象外
	LD	HL,DIR2		; DIR領域先頭
	LD	A,(HL)
	CP	080H		; SP-6110?
	JP	Z,SP_6110
;
; BOOTディスクは警告を出す
	LD	HL,DIR1		; ディスク先頭
	LD	A,(HL)
	CP	0C3H		; BOOTディスク?
	JR	NZ,MAKES1
;
; BOOTディスク警告
	CALL	LETNL		; 改行
	LD	DE,BTDSK
	CALL	MSG
	CALL	LETNL		; 改行
	CALL	BELL
	CALL	BELL

OWLP:
	LD	DE,BTDSKS
	CALL	MSG
	LD	DE,SELWK
	CALL	GETL		; 1ライン入力
	LD	HL,BTDSKSE - BTDSKS - 1	; 入力値格納 オフセット
	ADD	HL,DE		; 入力値格納アドレス
	LD	A,(HL)		; A<-入力値

	CP	'N'
	JP	Z,START		; プログラム先頭へ

	CP	'Y'
	JP	NZ,OWLP		; 再入力
;
;
MAKES1:
	LD	DE,LASTMG
	CALL	MSG
	CALL	LETNL		; 改行
MKSLP:
	LD	DE,LASTS
	CALL	MSG
	LD	DE,SELWK
	CALL	GETL		; 1ライン入力
	LD	HL,LASTSE - LASTS - 1	; 入力値格納 オフセット
	ADD	HL,DE		; 入力値格納アドレス
	LD	A,(HL)		; A<-入力値

	CP	'N'
	JP	Z,START		; プログラム先頭へ

	CP	'Y'
	JP	NZ,MKSLP	; 再入力
;
; ディスクに IPL SELECTER プログラムを書き込む
	LD	DE,MKMSG	; メッセージ表示
	CALL	MSG
	CALL	LETNL		; 改行
;
;
	LD	A,(BTDRV)	; TARGET ドライブ

;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BOOTディスク先頭から7セクタ書き込み
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	LD	A,(BTDRV)	; TARGETセレクト
	LD	(P_DIR),A	; ドライブ
	XOR	A
	LD	(P_TRK),A	; トラック0
	INC	A
	LD	(P_SEC),A	; セクタ1
	LD	HL,128*7	; 書き込みサイズ
	LD	(P_SIZ),HL
	LD	HL,PEND		; IPLSプログラム格納アドレス
	LD	(P_ADR),HL

	LD	IX,P_DIR

	CALL	SECT_WD		; 書き込み実行
	CALL	F_DMOFF		; ドライブ モータ オフ

	
	LD	DE,EKEMSG	; メッセージ表示
	CALL	MSG
	CALL	LETNL		; 改行

	JP	START		; プログラム先頭へ

;
;
; SP-6110 のディスクは対象外
SP_6110:
	LD	DE,NS_6110

MSGEX:
	CALL	LETNL		; 改行
	CALL	MSG
	CALL	LETNL		; 改行
;	CALL	BELL
;	CALL	BELL
	LD	A,5		; テンポ 3
	CALL	XTEMP
	LD	DE,ERBP		; ERROR音
	CALL	MELDY		; ERROR音
;
	JP	START		; プログラム先頭へ
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ディスクへ書き込み
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
SECT_WD:
;
	LD	A,00AH		; リトライ用カウンタ　セット
	LD	(M_RTRY),A

	CALL	F_REMD		; PRMドライブ (ドライブの起動)
	LD	A,(NNF8)	; 0nnF8Hのnn
	LD	B,A
	LD	C,0F8H

WDLP01:

	EXX			; 裏レジスタと入替

	LD	E,(IX+3)	; DE=サイズ (128の倍数で指定 0は不可)
	LD	D,(IX+4)
	RL	E		; DE * 2
	RL	D		; Dレジスタの回数分読込

	LD	C,IOFB		; IOFB
	LD	E,003H		; IOF9のbit1:DRDY、bit0:RQM

	LD	L,(IX+5)	; HL=ロードアドレス
	LD	H,(IX+6)

	CALL	F_READY		; FDCがREADYになるまで待つ
	XOR	A		; C=0
	LD	A,(IX+1)	; トラック番号
	RRA			; C->A7 >> A0->C (トラック番号÷2)
	OUT	(IOF9),A	; トラックの指定
	LD	A,(IX+2)	; セクタ番号
	JR	NC,SIDE		; サイド0の場合

	OR	080H		; C=1の時サイド1
SIDE:
	OUT	(IOF8),A	; サイド、セクタ
	CALL	F_WAIT1		; wait
	LD	A,0B0H		; M3=1,M2=0,M1=1,M0=1 SD Seek and Write Data
	LD	(L1000),A	; I/O:0FAHの出力内容保存
	DI			; 割り込み禁止
	OUT	(IOFA),A	; 出力 SEM=0B0H
WD_LP2:
	LD	B,080H		; 1セクタのバイト数
WD_LP1:
	IN	A,(IOF9)	; 入力 FDC
	AND	E		; IOF9のbit1:DRDY、bit0:RQM
	JR	Z,WD_LP1	; DRDY==0&RQM==0なら繰り返し

	RRCA			; C<-A0 >> A7<-A0
	JR	NC,WD_END	; RQM==0

	OUTI			; (HL)->IO(C) HL++ B--
	JP	NZ,WD_LP1	; Bレジスタで指定されたバイト数転送ループ

;    書き込み終了?
	DEC	D
	JR	NZ,WD_LP2	; 0じゃない場合

	EXX

	IN	A,(C)		; 準備してたポート0nnF8Hの入力(nnの出力)
;
; 書き込み終了
WD_END:
	CALL	F_ST		; FDCステータス
	RET	NC		; 書き込み完了

	LD	A,(M_RTRY)	; リトライカウンター --
	DEC	A
	LD	(M_RTRY),A
	JP	Z,E_HOOK	; リトライ回数切れの場合

	CALL	F_SZERO		; シーク ゼロ
	JP	SECT_WD		; 書き込みリトライ
;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  エラーフック
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ER_HOOK:
	LD	SP,010F0H	; スタックポインタ初期化
	CALL	LETNL
	LD	DE,EH_MSG	; エラーフック メッセージ表示
	CALL	MSG
	CALL	F_DMOFF		; ドライブ モータ オフ
	JP	START		; プログラム先頭へ戻る

EH_MSG:	DB	"ERROR (HOOK)",00DH


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  各種データ・エリア
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

			; オープニング メッセージ
	;	 ----+----1----+----2----+----3----+----4
OPMSG1:	DB	"IPL SELECTER MAKER FOR MZ-80K/C,1200    "
	DB	"       VER.0.3  2021.02.22 HIDEKI SUGA", 00DH

OPMSG2:	DB	"SET SLAVE DISK(SP-6010)",00DH

	;	 ----+----1----+----2----+----3----+----4
SELMSG:	DB	"TAEGET DRIVE [1-4/!:MON] ?",00DH
SELMSGE:

NS_6110:
	DB	"ERR:SORRY SP-6110 IS NOT SUPPORTED",00DH

	;	 ----+----1----+----2----+----3----+----4
BTDSK:	DB	"ATTENTION!  THIS IS BOOT DISK!!",00DH
BTDSKS:	DB	"DO YOU WANT TO OVERWRITE? [Y/N] ?",00DH
BTDSKSE:

LASTMG:	DB	"FINAL CONFIRMATION.",00DH
LASTS:	DB	"DO YOU WANT TO MAKE DISK? [Y/N] ?",00DH
LASTSE:

ERBP:	DB	0D7H,"C1C5",00DH

MKMSG:	DB	"MAKEING",00DH

EKEMSG:	DB	"END",00DH

LDGMSG:	DB	"LOADING ",00DH


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  リードパラメータ
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; 初期値は、ディレクトリ情報読込
P_DIR:	DB	0		; ドライブ	(IX)
P_TRK:	DB	1		; トラック番号	(IX+1)
P_SEC:	DB	1		; セクタ番号	(IX+2)
P_SIZ:	DW	128 * 1		; 読込サイズ	(IX+3)(IX+4)
P_ADR:	DW	DIR1		; ロードアドレス(IX+5)(IX+6)
	DB	0		; アクセス中のトラック
	DB	0		; アクセス中のセクタ

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  最大アドレス
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
PEND:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  IPL SELECTER 埋め込み
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	BINCLUDE	"IPLSKC.bin"

DEND:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ワークエリア等
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DIR1	EQU	DEND		; ディスク先頭読込先
DIR2	EQU	DIR1 + 0100H	; ディレクトリ領域先頭読込先
SELWK	EQU	DIR2 + 0100H	; セレクト入力ワーク

	END
