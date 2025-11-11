;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ＩＰＬセレクタ for MZ-80K/C・1200
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  作成：菅　秀樹
;;  履歴：Ver 0.1 2020年12月12日 初回リリース
;;        Ver 0.2 2020年12月12日 制御移行前にSPを初期化
;;        Ver 0.3 2021年02月22日 ディスク読込時以外はモーターOFF
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;　モニタ&FD-IF ROM内ルーチン等
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

STACKP	EQU	010F0H	; スタック ポインター

F_DMON	EQU	0F090H	; ドライブ モータ オン
F_DMOFF	EQU	0F0A7H	; ドライブ モータ オフ
F_SZERO	EQU	0F0B2H	; シーク ゼロ
F_READY	EQU	0F0BDH	; FDCがREADYになるまで待つ
F_ST	EQU	0F0D9H	; FDCステータス
F_REMD	EQU	0F0FFH	; PRMドライブ (ドライブの起動)
F_LOAD	EQU	0F13BH	; FD読込

LF1A6	EQU	0F1A6H	; wait

IOF8	EQU	0F8H	; SES
IOF9	EQU	0F9H	; FDC
IOFA	EQU	0FAH	; SME
IOFB	EQU	0FBH	; PRM



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ワークエリア等
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DIR1	EQU	08000H	; ディレクトリ領域読込先～086FFH
DIR1SIZ	EQU	00040H	; ディレクトリ領域 1項目のサイズ
DIR2	EQU	08800H	; ファイル名一覧 ～08A43H (20byte * 29)
DIR2SIZ	EQU	20	; ファイル名 1項目のサイズ (20byte)
DIR3	EQU	08B00H	; OBJ 一覧 ～ BPR - 1
	; トラック(1)、セクタ(1)、サイズ(2)、先頭アドレス(2)、実行アドレス(2)
DIR3SIZ	EQU	8	; OBJ 1項目のサイズ (8byte)

BPR	EQU	DIR3 + DIR3SIZ * 29	; (DB * 20)BOOT対象表示用
BPRD	EQU	BPR + 20		; (DB) 〃 文末

MAXDIR	EQU	08C00H	; (DB)最大オブジェクト数
CHKDIR	EQU	08C01H	; (DB)チェック中ディレクトリ

LOAD01	EQU	08C02H	; (DW)ディレクトリ
LIST01	EQU	08C04H	; (DW)リスト
LIST02	EQU	08C06H	; (DW)リスト表示用
DIR3WK	EQU	08C08H	; (DW)OBJ用

LISTC	EQU	08C0AH	; (DB)一覧表示用カウンター

BOOTN	EQU	08C0BH	; (DB)BOOTセレクト

BOBJ	EQU	08C0CH	; (DW) BOOT OBJ 情報格納アドレス

SELWK	EQU	08F00H	; BOOTセレクト 入力ワーク

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  MZT ヘッダ
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
START0	EQU	09800H

;	ORG	START0 - 00080H
;
;;	* テープヘッダー
;	DB	001H		; OBJ
;;		 ----+----1----+--
;	DB	"IPL SELECTER K/C"
;	DB	00DH
;
;	ORG	START0 - 0006EH
;	DW	PEND - START0		; サイズ
;	DW	START0			; ロード・アドレス
;	DW	START0			; ジャンプ・アドレス



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  メイン
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	ORG	START0
	JP	START		; 0C3H がBOOTシグネチャ
START:
;
	LD	A,00AH		; リトライ用カウンタ　セット
	LD	(M_RTRY),A
;
	LD	A,0C3H		; エラーフック設定
	LD	(E_HOOK),A
	LD	HL,ER_HOOK
	LD	(E_HOOK + 1),HL
;
; オープニング メッセージ表示
	CALL	LETNL		; 改行
	CALL	LETNL		; 改行
	LD	DE,OPMSG1	; OP1
	CALL	MSG
	CALL	LETNL		; 改行
;;	LD	DE,OPMSG2	; OP2
;;	CALL	MSG
	CALL	LETNL		; 改行
;
; ワークエリア　クリア
;   DIR2 をスペースで埋める
	LD	A,' '	; SPACE
	LD	HL,DIR2
	LD	(HL),A
	LD	DE,DIR2 + 1
	LD	BC,DIR2SIZ * 29
	LDIR
;
;   ゼロクリア
	XOR	A
	LD	(MAXDIR),A
	LD	(CHKDIR),A
	LD	(LISTC),A
;     DIR3 を0で埋める
	LD	(DIR3),A
	LD	HL,DIR3
	LD	(HL),A
	LD	DE,DIR3 + 1
	LD	BC,DIR3SIZ * 29
	LDIR
	
;
;   初期値設定
	LD	HL,DIR1
	LD	(LOAD01),HL
	LD	HL,DIR2
	LD	(LIST01),HL
	LD	HL,DIR3
	LD	(DIR3WK),HL
;
;
;   起動ドライブ番号をセット
	LD	A,(BTDRV)
	LD	(P_DIR),A
;   読込(FD-ROM内ルーチン使用)
	LD	IX,P_DIR
	CALL	F_LOAD
	CALL	F_DMOFF		; ドライブ モータ オフ
;
;
; SP-6110 のディスクは対象外
	LD	HL,(LOAD01)
	LD	A,(HL)
	CP	080H	; SP-6110
	JP	Z,SP_6110
;
;
; ディレクトリからOBJを抽出
;   OBJ抽出ループ
CFMDLP:
	LD	HL,(LOAD01)
	LD	A,(HL)
	CP	001H	; OBJ ?
	JR	NZ,CFMDNX
;
;   OBJの場合
;     ファイル名の前にA～Z:を追加
	LD	A,(MAXDIR)
	INC	A
	LD	(MAXDIR),A
	ADD	A,'A' - 1
;
	LD	DE,(LIST01)
	LD	(DE),A
	INC	DE
	LD	A,':'
	LD	(DE),A
	INC	DE
;
	INC	HL	; モード スキップ
;
;     ファイル名転送
	LD	B,16
FNLP:
	LD	A,(HL)
	CP	00DH
	JR	Z,FNLPE
	LD	(DE),A
	INC	HL
	INC	DE
	DEC	B
	JR	NZ,FNLP

FNLPE:
;

;     トラック、セクタ 転送
	LD	HL,(LOAD01)
	LD	BC,0003EH
	ADD	HL,BC
	LD	DE,(DIR3WK)
	LD	BC,2
	LDIR
;
;      サイズ(2)、先頭アドレス(2)、実行アドレス(2)転送
	LD	HL,(LOAD01)
	LD	BC,00012H
	ADD	HL,BC
	LD	BC,6
	LDIR
;
;     次の ファイル名一覧 アドレスへ
	LD	HL,(LIST01)
	LD	BC,DIR2SIZ
	ADD	HL,BC
	LD	(LIST01),HL
;
;     次の OBJ アドレスへ
	LD	HL,(DIR3WK)
	LD	DE,DIR3SIZ
	ADD	HL,DE
	LD	(DIR3WK),HL
;
;   次のディレクトリ情報へ
CFMDNX:	LD	HL,(LOAD01)
	LD	DE,DIR1SIZ
	ADD	HL,DE
	LD	(LOAD01),HL
;
;     DIR 数 UP
	LD	A,(CHKDIR)
	INC	A
	LD	(CHKDIR),A
	CP	26		; ディレクトリ情報は最大26個(A-Z)
	JR	NZ,CFMDLP

CFMDEX:

;
; OBJが無い場合メッセージを表示して終了
	LD	A,(MAXDIR)
	CP	0
	JR	NZ,PDIR
	
	LD	DE,NOOBJ	; NO OBJ FILE

MSGEX:	CALL	MSG
	CALL	LETNL		; 改行
;	CALL	BELL
;	CALL	BELL
	LD	A,5		; テンポ 3
	CALL	XTEMP
	LD	DE,ERBP		; ERROR音
	CALL	MELDY		; ERROR音
;
	JP	ST1		; モニタに戻る
;
; SP-6110 のディスクは対象外
SP_6110:
	LD	DE,NS_6110
	JR	MSGEX
;
; OBJ一覧表示
PDIR:
;    リストの最後に 00DH を入れる
	LD	HL,(LIST01)
	DEC	HL
	LD	A,00DH
	LD	(HL),A
;
;
PDIR2:
	LD	DE,DIR2
	CALL	LIST		; ファイル一覧リスト表示
	CALL	LETNL		; 改行
	CALL	LETNL		; 改行
;
PSEL:
	LD	DE,SELMSG	; セレクトメッセージ表示
	CALL	MSG

	LD	DE,SELWK
	CALL	GETL		; 1ライン入力
;;	LD	HL,00FH		; 
	LD	HL,SELMSGE - SELMSG - 1	; 入力値格納 オフセット
	ADD	HL,DE		; 入力値格納アドレス
	LD	A,(HL)		; A<-入力値

	CP	'!'
	JP	Z,ST1		; モニタに戻る

	CP	'#'
	JR	Z,PDIR2		; リスト再描画

	SUB	'A'		; 'A'～'Z' -> 0～26
	JR	C,PSEL		; A未満?

	LD	(BOOTN),A	; BOOTセレクト保存

	LD	B,A
	LD	A,(MAXDIR)
	DEC	A
	CP	B
	JR	C,PSEL		; MAXDIR以上?

;    BOOT
;
	LD	A,(BOOTN)	; BOOTセレクト
;      ファイル名
	LD	BC,DIR2SIZ
	LD	HL,DIR2

	CP	0
	JR	Z,OFNLPE
OFNLP:
	ADD	HL,BC
	DEC	A
	JR	NZ,OFNLP
OFNLPE:

	LD	DE,BPR		; ファイル名をBOOT対象表示用エリアに転送
	LD	BC,DIR2SIZ
	LDIR
	LD	A,00DH		; 文末に 00DH を格納
	LD	(BPRD),A

	CALL	LETNL		; 改行
	LD	DE,LDGMSG	; ローディングMSG
	CALL	MSG
	LD	DE,BPR + 2	; ファイル名表示
	CALL	MSG
	CALL	LETNL		; 改行
;
;      OBJ
	LD	BC,DIR3SIZ
	LD	HL,DIR3
	LD	A,(BOOTN)

	CP	0
	JR	Z,OBNLPE
OBNLP:
	ADD	HL,BC
	DEC	A
	JR	NZ,OBNLP
OBNLPE:

	LD	(BOBJ),HL

;	LD	DE,MTRK		; トラック
;	CALL	MSG
;	LD	A,(HL)
;	CALL	PRTBYT
;	INC	HL
;
;	LD	DE,MSCT		; セクター
;	CALL	MSG
;	LD	A,(HL)
;	CALL	PRTBYT
;	INC	HL
;
;	LD	DE,MSIZ		; サイズ
;	CALL	DWRD
;
;	LD	DE,MLOD		; ロード
;	CALL	DWRD
;
;	LD	DE,MJMP		; ジャンプ
;	CALL	DWRD
;
;	CALL	LETNL		; 改行
;	CALL	LETNL		; 改行


;; test
;	JP	PDIR2


;   OBJ 読込パラメータ
;	LD	HL,(BOBJ)

;     トラック、セクタ
	CALL	LDDEHL		; LD DE,(HL)
	PUSH	HL
	LD	HL,P_TRK
	CALL	LDHLDE		; LD (HL),DE
	POP	HL
;     読込みサイズ
	INC	HL
	INC	HL
	CALL	LDDEHL		; LD DE,(HL)
	PUSH	HL
	LD	HL,P_SIZ
	CALL	LDHLDE		; LD (HL),DE
	POP	HL
;     先頭アドレス
	INC	HL
	INC	HL
	CALL	LDDEHL		; LD DE,(HL)
	PUSH	HL
	LD	HL,P_ADR
	CALL	LDHLDE		; LD (HL),DE
	POP	HL
;
;  ディスクからファイル読込
	LD	IX,P_DIR	; 読込パラメータ
	CALL	FILE_RD
	CALL	F_DMOFF		; ドライブ モータ オフ
;
;  読込んだファイルを実行
	LD	SP,STACKP	; スタック ポインター再設定

	LD	HL,(BOBJ)	; OBJ値格納アドレス→HL
	LD	BC,6		; 実行アドレス オフセット値
	ADD	HL,BC

	LD	E,(HL)		; LD HL,(HL)
	INC	HL
	LD	D,(HL)
	EX	DE,HL

	JP	(HL)		; 実行アドレスへ

;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  ディスクからファイル読込
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
FILE_RD:
;
	LD	A,00AH		; リトライ用カウンタ　セット
	LD	(M_RTRY),A

	CALL	F_REMD		; PRMドライブ (ドライブの起動)
	LD	A,(NNF8)	; 0nnF8Hのnn
	LD	B,A
	LD	C,0F8H

RDLP01:

	EXX			; 裏レジスタと入替

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
	CALL	LF1A6		; wait
	LD	A,070H		; M3=0,M2=1,M1=1,M0=1
	LD	(L1000),A	; I/O:0FAHの出力内容保存
	DI			; 割り込み禁止
	OUT	(IOFA),A	; 出力 SEM=070H

	LD	B,080H		; 1セクタのバイト数
RD_LP1:
	IN	A,(IOF9)	; 入力 FDC
	AND	E		; IOF9のbit1:DRDY、bit0:RQM
	JR	Z,RD_LP1	; DRDY==0&RQM==0なら繰り返し

	RRCA			; C<-A0 >> A7<-A0
	JR	NC,RD_END	; RQM==0

	INI			; IO(C)->(HL) HL++ B--
	JP	NZ,RD_LP1	; Bレジスタで指定されたバイト数転送ループ

	EXX

	IN	A,(C)		; 準備してたポート0nnF8Hの入力(nnの出力)
;
; 1セクタ読込終了

;    次のロードアドレス計算・セット
	LD	L,(IX+5)	; HL=ロードアドレス
	LD	H,(IX+6)
	LD	BC,0007EH	; 1セクタ中有効バイト数
	ADD	HL,BC		; 次のロードアドレス計算
	LD	(IX+5),L	; 次のロードアドレスセット
	LD	(IX+6),H

;    次のトラック、セクタ(読込んだセクタの007EH,007FH)セット
	LD	A,(HL)
	LD	(IX+1),A	; トラック番号
	INC	HL
	LD	A,(HL)
	LD	(IX+2),A	; セクタ番号

;    ファイル最終セクタ？(トラック番号、セクタ番号共に000H)
	LD	A,(IX+1)	; トラック番号
	OR	A
	JR	NZ,RDLP01	; 0じゃない場合
	LD	A,(IX+2)	; セクタ番号
	OR	A
	JR	NZ,RDLP01	; 0じゃない場合

;    最終セクタの場合

;    リード終了
RD_END:
	CALL	F_ST		; FDCステータス
	RET	NC		; 読込完了

	LD	A,(M_RTRY)	; リトライカウンター --
	DEC	A
	LD	(M_RTRY),A
	JP	Z,E_HOOK	; リトライ回数切れの場合

	CALL	F_SZERO		; シーク ゼロ
	JP	FILE_RD		; 読込リトライ



DWRD:
	CALL	MSG
	LD	A,(HL)
	LD	E,A
	INC	HL
	LD	A,(HL)
	LD	D,A
	INC	HL
	PUSH	HL
	PUSH	DE
	POP	HL
	CALL	PRTWRD
	POP	HL

	RET
;
;	HLレジスタで示すアドレスからWORD(2byite)をDEレジスタに読込む
LDDEHL:
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	DEC	HL
	RET
;
;	HLレジスタで示すアドレスへDEレジスタの内容をWORD(2byite)で書込む
LDHLDE:
	LD	(HL),E
	INC	HL
	LD	(HL),D
	DEC	HL
	RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  エラーフック
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ER_HOOK:
	LD	SP,010F0H	; スタックポインタ初期化
	CALL	LETNL
	LD	DE,EH_MSG	; エラーフック メッセージ表示
	CALL	MSG
	CALL	F_DMOFF		; ドライブ モータ オフ
	JP	ST1		; モニタへ戻る

EH_MSG:	DB	"ERROR (HOOK)",00DH


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  各種データ・エリア
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

			; オープニング メッセージ
	;	 ----+----1----+----2----+----3----+----4
OPMSG1:	DB	"=== IPL SELECTER FOR MZ-80K/C,1200 ===  "
	DB	"       VER.0.3  2021.02.22 HIDEKI SUGA", 00DH

NOOBJ:	DB	"NO OBJ FILE",00DH

	;	 ----+----1----+----2----+----3----+----4
SELMSG:	DB	"BOOT SELECT [!:MON #:LIST] => ",00DH
SELMSGE:

NS_6110:
	DB	"ERR:SORRY SP-6110 IS NOT SUPPORTED",00DH

ERBP:	DB	0D7H,"C1C5",00DH

LDGMSG:	DB	"LOADING ",00DH

;MTRK:	DB	"T:",00DH
;MSCT:	DB	" S:",00DH
;MSIZ:	DB	" SIZ:",00DH
;MLOD:	DB	" LOD:",00DH
;MJMP:	DB	" JMP:",00DH

;MSIZ:	DB	" SIZE:$",00DH
;MLOD:	DB	" LODAD:$",00DH
;MJMP:	DB	" JMP:$",00DH



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  リードパラメータ
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; 初期値は、ディレクトリ情報読込
P_DIR:	DB	0		; ドライブ	(IX)
P_TRK:	DB	1		; トラック番号	(IX+1)
P_SEC:	DB	1		; セクタ番号	(IX+2)
P_SIZ:	DW	128 * 14	; 読込サイズ	(IX+3)(IX+4)
P_ADR:	DW	DIR1		; ロードアドレス(IX+5)(IX+6)
	DB	0		; アクセス中のトラック
	DB	0		; アクセス中のセクタ

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  最大アドレス
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
PEND:

PLIMIT	EQU	09800H + 128 * 7
;
	DS	PLIMIT - PEND

	END
