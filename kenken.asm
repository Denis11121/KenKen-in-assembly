.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Exemplu proiect desenare",0
area_width EQU 1280
area_height EQU 720
area DD 0

counter DD 0 ; numara evenimentele de tip timer

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

button_x EQU 250
button_y EQU 150
button_size_celula EQU 80
button_size_tabel EQU 420

casuta1_x EQU 250
casuta1_y EQU 150

var_x DD 0
var_y DD 0
var_cifra DD 0


matrice_introdusa DD 0, 0, 0, 0, 0, 0
				  DD 0, 0, 0, 0, 0, 0
			      DD 0, 0, 0, 0, 0, 0
			      DD 0, 0, 0, 0, 0, 0
	     		  DD 0, 0, 0, 0, 0, 0
			      DD 0, 0, 0, 0, 0, 0
				   
matrice_raspunsuri DD 5, 6, 3, 4, 1, 2 
                   DD 6, 1, 4, 5, 2, 3 
				   DD 4, 5, 2, 3, 6, 1
				   DD 3, 4, 1, 2, 5, 6
				   DD 2, 3, 6, 1, 4, 5
				   DD 1, 2, 5, 6, 3, 4
				   

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text

	
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters

draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

line_horizontal macro x,y,len,color
local bucla_line
	mov eax, y ;eax=y
	mov ebx, area_width
	mul ebx ;eax=y*area_width
	add eax, x ; eax=y*area_width+x
	shl eax, 2 ;eax=(y*area_width+x)*4
	add eax, area
	mov ecx,len
bucla_line:
	mov dword ptr[eax],color
	add eax,4
	loop bucla_line
endm

line_vertical macro x,y,len,color
local bucla_line
	mov eax, y ;eax=y
	mov ebx, area_width
	mul ebx ;eax=y*area_width
	add eax, x ; eax=y*area_width+x
	shl eax, 2 ;eax=(y*area_width+x)*4
	add eax, area
	mov ecx,len
bucla_line:
	mov dword ptr[eax],color
	add eax,4*area_width
	loop bucla_line
endm

line_oblique_r macro x,y,len,color
local bucla_line
mov eax, y;
mov ebx, area_width
mul ebx
add eax, x
shl eax, 2
add eax, area
	mov ecx,len
bucla_line:
mov dword ptr[eax],color
	add eax,4*area_width+4
	loop bucla_line
endm

line_oblique_l macro x,y,len,color
local bucla_line
mov eax, y;
mov ebx, area_width
mul ebx
add eax, x
shl eax, 2
add eax, area
	mov ecx,len
bucla_line:
mov dword ptr[eax],color
	add eax,4*area_width-4
	loop bucla_line
endm

 
; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	cmp eax, 3
	jz evt_key ; s-a apasat o tasta
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_litere
	



	
scrie_pozitionare macro x,y,casuta_x,casuta_y
local button_fail
make_text_macro 'A', area, casuta_x+20, casuta_y+60
make_text_macro 'I', area, casuta_x+30, casuta_y+60
make_text_macro 'C', area, casuta_x+40, casuta_y+60
make_text_macro 'I', area, casuta_x+50, casuta_y+60
endm 

button_fail macro casuta_x,casuta_y
make_text_macro ' ', area, casuta_x+20, casuta_y+60
make_text_macro ' ', area, casuta_x+30, casuta_y+60
make_text_macro ' ', area, casuta_x+40, casuta_y+60
make_text_macro ' ', area, casuta_x+50, casuta_y+60

make_text_macro ' ', area, casuta_x+20+80, casuta_y+60
make_text_macro ' ', area, casuta_x+30+80, casuta_y+60
make_text_macro ' ', area, casuta_x+40+80, casuta_y+60
make_text_macro ' ', area, casuta_x+50+80, casuta_y+60

make_text_macro ' ', area, casuta_x+20+80*2, casuta_y+60
make_text_macro ' ', area, casuta_x+30+80*2, casuta_y+60
make_text_macro ' ', area, casuta_x+40+80*2, casuta_y+60
make_text_macro ' ', area, casuta_x+50+80*2, casuta_y+60

make_text_macro ' ', area, casuta_x+20+80*3, casuta_y+60
make_text_macro ' ', area, casuta_x+30+80*3, casuta_y+60
make_text_macro ' ', area, casuta_x+40+80*3, casuta_y+60
make_text_macro ' ', area, casuta_x+50+80*3, casuta_y+60

make_text_macro ' ', area, casuta_x+20+80*4, casuta_y+60
make_text_macro ' ', area, casuta_x+30+80*4, casuta_y+60
make_text_macro ' ', area, casuta_x+40+80*4, casuta_y+60
make_text_macro ' ', area, casuta_x+50+80*4, casuta_y+60

make_text_macro ' ', area, casuta_x+20+80*5, casuta_y+60
make_text_macro ' ', area, casuta_x+30+80*5, casuta_y+60
make_text_macro ' ', area, casuta_x+40+80*5, casuta_y+60
make_text_macro ' ', area, casuta_x+50+80*5, casuta_y+60

make_text_macro ' ', area, casuta_x+20, casuta_y+60+80
make_text_macro ' ', area, casuta_x+30, casuta_y+60+80
make_text_macro ' ', area, casuta_x+40, casuta_y+60+80
make_text_macro ' ', area, casuta_x+50, casuta_y+60+80

make_text_macro ' ', area, casuta_x+20+80, casuta_y+60+80
make_text_macro ' ', area, casuta_x+30+80, casuta_y+60+80
make_text_macro ' ', area, casuta_x+40+80, casuta_y+60+80
make_text_macro ' ', area, casuta_x+50+80, casuta_y+60+80

make_text_macro ' ', area, casuta_x+20+80*2, casuta_y+60+80
make_text_macro ' ', area, casuta_x+30+80*2, casuta_y+60+80
make_text_macro ' ', area, casuta_x+40+80*2, casuta_y+60+80
make_text_macro ' ', area, casuta_x+50+80*2, casuta_y+60+80

make_text_macro ' ', area, casuta_x+20+80*3, casuta_y+60+80
make_text_macro ' ', area, casuta_x+30+80*3, casuta_y+60+80
make_text_macro ' ', area, casuta_x+40+80*3, casuta_y+60+80
make_text_macro ' ', area, casuta_x+50+80*3, casuta_y+60+80

make_text_macro ' ', area, casuta_x+20+80*4, casuta_y+60+80
make_text_macro ' ', area, casuta_x+30+80*4, casuta_y+60+80
make_text_macro ' ', area, casuta_x+40+80*4, casuta_y+60+80
make_text_macro ' ', area, casuta_x+50+80*4, casuta_y+60+80

make_text_macro ' ', area, casuta_x+20+80*5, casuta_y+60+80
make_text_macro ' ', area, casuta_x+30+80*5, casuta_y+60+80
make_text_macro ' ', area, casuta_x+40+80*5, casuta_y+60+80
make_text_macro ' ', area, casuta_x+50+80*5, casuta_y+60+80

make_text_macro ' ', area, casuta_x+20, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+30, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+40, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+50, casuta_y+60+80*2

make_text_macro ' ', area, casuta_x+20+80, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+30+80, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+40+80, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+50+80, casuta_y+60+80*2

make_text_macro ' ', area, casuta_x+20+80*2, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+30+80*2, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+40+80*2, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+50+80*2, casuta_y+60+80*2

make_text_macro ' ', area, casuta_x+20+80*3, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+30+80*3, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+40+80*3, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+50+80*3, casuta_y+60+80*2

make_text_macro ' ', area, casuta_x+20+80*4, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+30+80*4, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+40+80*4, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+50+80*4, casuta_y+60+80*2

make_text_macro ' ', area, casuta_x+20+80*5, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+30+80*5, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+40+80*5, casuta_y+60+80*2
make_text_macro ' ', area, casuta_x+50+80*5, casuta_y+60+80*2

make_text_macro ' ', area, casuta_x+20, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+30, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+40, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+50, casuta_y+60+80*3

make_text_macro ' ', area, casuta_x+20+80, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+30+80, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+40+80, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+50+80, casuta_y+60+80*3

make_text_macro ' ', area, casuta_x+20+80*2, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+30+80*2, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+40+80*2, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+50+80*2, casuta_y+60+80*3

make_text_macro ' ', area, casuta_x+20+80*3, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+30+80*3, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+40+80*3, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+50+80*3, casuta_y+60+80*3

make_text_macro ' ', area, casuta_x+20+80*4, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+30+80*4, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+40+80*4, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+50+80*4, casuta_y+60+80*3

make_text_macro ' ', area, casuta_x+20+80*5, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+30+80*5, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+40+80*5, casuta_y+60+80*3
make_text_macro ' ', area, casuta_x+50+80*5, casuta_y+60+80*3

make_text_macro ' ', area, casuta_x+20, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+30, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+40, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+50, casuta_y+60+80*4

make_text_macro ' ', area, casuta_x+20+80, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+30+80, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+40+80, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+50+80, casuta_y+60+80*4

make_text_macro ' ', area, casuta_x+20+80*2, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+30+80*2, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+40+80*2, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+50+80*2, casuta_y+60+80*4

make_text_macro ' ', area, casuta_x+20+80*3, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+30+80*3, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+40+80*3, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+50+80*3, casuta_y+60+80*4

make_text_macro ' ', area, casuta_x+20+80*4, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+30+80*4, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+40+80*4, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+50+80*4, casuta_y+60+80*4

make_text_macro ' ', area, casuta_x+20+80*5, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+30+80*5, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+40+80*5, casuta_y+60+80*4
make_text_macro ' ', area, casuta_x+50+80*5, casuta_y+60+80*4

make_text_macro ' ', area, casuta_x+20, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+30, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+40, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+50, casuta_y+60+80*5

make_text_macro ' ', area, casuta_x+20+80, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+30+80, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+40+80, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+50+80, casuta_y+60+80*5

make_text_macro ' ', area, casuta_x+20+80*2, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+30+80*2, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+40+80*2, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+50+80*2, casuta_y+60+80*5

make_text_macro ' ', area, casuta_x+20+80*3, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+30+80*3, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+40+80*3, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+50+80*3, casuta_y+60+80*5

make_text_macro ' ', area, casuta_x+20+80*4, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+30+80*4, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+40+80*4, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+50+80*4, casuta_y+60+80*5

make_text_macro ' ', area, casuta_x+20+80*5, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+30+80*5, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+40+80*5, casuta_y+60+80*5
make_text_macro ' ', area, casuta_x+50+80*5, casuta_y+60+80*5
endm  

scrie_cifra macro x,y,casuta_x,casuta_y,cifra,poz_matrice
local scrie_2,scrie_3,scrie_4,scrie_5,scrie_6
mov ebx, poz_matrice
mov dword ptr matrice_introdusa[ebx],cifra

cmp cifra,1
jne scrie_2
make_text_macro '1', area, casuta_x+20, casuta_y+30

jmp afisare_litere
scrie_2:
cmp cifra,2
jne scrie_3
make_text_macro '2', area, casuta_x+20, casuta_y+30
jmp afisare_litere

scrie_3:
cmp cifra,3
jne scrie_4
make_text_macro '3', area, casuta_x+20, casuta_y+30
jmp afisare_litere

scrie_4:
cmp cifra,4
jne scrie_5
make_text_macro '4', area, casuta_x+20, casuta_y+30
jmp afisare_litere

scrie_5:
cmp cifra,5
jne scrie_6
make_text_macro '5', area, casuta_x+20, casuta_y+30
jmp afisare_litere

scrie_6:
cmp cifra,6
make_text_macro '6', area, casuta_x+20, casuta_y+30
jmp afisare_litere

endm 

evt_key:
mov eax,[ebp+arg2]
sub eax, '0'
mov var_cifra,eax

cmp var_y, casuta1_y+80
jl linie1_1
 cmp var_y, casuta1_y+80*2
jl linie2_1
  cmp var_y, casuta1_y+80*3
 jl linie3_1
  cmp var_y, casuta1_y+80*4
 jl linie4_1
  cmp var_y, casuta1_y+80*5
 jl linie5_1
  cmp var_y, casuta1_y+80*6
 jl linie6_1
 
linie1_1:
cmp var_x, casuta1_x+80
jl button1_1
cmp var_x, casuta1_x+80*2
jl button2_1
cmp var_x, casuta1_x+80*3
jl button3_1
cmp var_x, casuta1_x+80*4
jl button4_1
cmp var_x, casuta1_x+80*5
jl button5_1
cmp var_x, casuta1_x+80*6
jl button6_1


button1_1:
scrie_cifra var_x,var_y,casuta1_x,casuta1_y,eax,0
jmp afisare_litere
button2_1:
scrie_cifra var_x,var_y,casuta1_x+80,casuta1_y,eax,4
jmp afisare_litere
button3_1:
scrie_cifra var_x,var_y,casuta1_x+80*2,casuta1_y,eax,8
jmp afisare_litere
button4_1:
scrie_cifra var_x,var_y,casuta1_x+80*3,casuta1_y,eax,12
jmp afisare_litere
button5_1:
scrie_cifra var_x,var_y,casuta1_x+80*4,casuta1_y,eax,16
jmp afisare_litere
button6_1:
scrie_cifra var_x,var_y,casuta1_x+80*5,casuta1_y,eax,20
jmp afisare_litere

linie2_1:
cmp var_x, casuta1_x+80
jl button7_1
cmp var_x, casuta1_x+80*2
jl button8_1
cmp var_x, casuta1_x+80*3
jl button9_1
cmp var_x, casuta1_x+80*4
jl button10_1
cmp var_x, casuta1_x+80*5
jl button11_1
cmp var_x, casuta1_x+80*6
jl button12_1

button7_1:
scrie_cifra var_x,var_y,casuta1_x,casuta1_y+80,eax,24 
jmp afisare_litere
button8_1:
scrie_cifra var_x,var_y,casuta1_x+80,casuta1_y+80,eax,28
jmp afisare_litere
button9_1:
scrie_cifra var_x,var_y,casuta1_x+80*2,casuta1_y+80,eax,32
jmp afisare_litere
button10_1:
scrie_cifra var_x,var_y,casuta1_x+80*3,casuta1_y+80,eax,36
jmp afisare_litere
button11_1:
scrie_cifra var_x,var_y,casuta1_x+80*4,casuta1_y+80,eax,40
jmp afisare_litere
button12_1:
scrie_cifra var_x,var_y,casuta1_x+80*5,casuta1_y+80,eax,44
jmp afisare_litere

linie3_1:
cmp var_x, casuta1_x+80
jl button13_1
cmp var_x, casuta1_x+80*2
jl button14_1
cmp var_x, casuta1_x+80*3
jl button15_1
cmp var_x, casuta1_x+80*4
jl button16_1
cmp var_x, casuta1_x+80*5
jl button17_1
cmp var_x, casuta1_x+80*6
jl button18_1

button13_1:
scrie_cifra var_x,var_y,casuta1_x,casuta1_y+80*2,eax,48 
jmp afisare_litere
button14_1:
scrie_cifra var_x,var_y,casuta1_x+80,casuta1_y+80*2,eax,52
jmp afisare_litere
button15_1:
scrie_cifra var_x,var_y,casuta1_x+80*2,casuta1_y+80*2,eax,56
jmp afisare_litere
button16_1:
scrie_cifra var_x,var_y,casuta1_x+80*3,casuta1_y+80*2,eax,60
jmp afisare_litere
button17_1:
scrie_cifra var_x,var_y,casuta1_x+80*4,casuta1_y+80*2,eax,64
jmp afisare_litere
button18_1:
scrie_cifra var_x,var_y,casuta1_x+80*5,casuta1_y+80*2,eax,68
jmp afisare_litere

linie4_1:
cmp var_x, casuta1_x+80
jl button19_1
cmp var_x, casuta1_x+80*2
jl button20_1
cmp var_x, casuta1_x+80*3
jl button21_1
cmp var_x, casuta1_x+80*4
jl button22_1
cmp var_x, casuta1_x+80*5
jl button23_1
cmp var_x, casuta1_x+80*6
jl button24_1

button19_1:
scrie_cifra var_x,var_y,casuta1_x,casuta1_y+80*3,eax,72 
jmp afisare_litere
button20_1:
scrie_cifra var_x,var_y,casuta1_x+80,casuta1_y+80*3,eax,76
jmp afisare_litere
button21_1:
scrie_cifra var_x,var_y,casuta1_x+80*2,casuta1_y+80*3,eax,80
jmp afisare_litere
button22_1:
scrie_cifra var_x,var_y,casuta1_x+80*3,casuta1_y+80*3,eax,84
jmp afisare_litere
button23_1:
scrie_cifra var_x,var_y,casuta1_x+80*4,casuta1_y+80*3,eax,88
jmp afisare_litere
button24_1:
scrie_cifra var_x,var_y,casuta1_x+80*5,casuta1_y+80*3,eax,92
jmp afisare_litere

linie5_1:
cmp var_x, casuta1_x+80
jl button25_1
cmp var_x, casuta1_x+80*2
jl button26_1
cmp var_x, casuta1_x+80*3
jl button27_1
cmp var_x, casuta1_x+80*4
jl button28_1
cmp var_x, casuta1_x+80*5
jl button29_1
cmp var_x, casuta1_x+80*6
jl button30_1

button25_1:
scrie_cifra var_x,var_y,casuta1_x,casuta1_y+80*4,eax,96 
jmp afisare_litere
button26_1:
scrie_cifra var_x,var_y,casuta1_x+80,casuta1_y+80*4,eax,100
jmp afisare_litere
button27_1:
scrie_cifra var_x,var_y,casuta1_x+80*2,casuta1_y+80*4,eax,104
jmp afisare_litere
button28_1:
scrie_cifra var_x,var_y,casuta1_x+80*3,casuta1_y+80*4,eax,108
jmp afisare_litere
button29_1:
scrie_cifra var_x,var_y,casuta1_x+80*4,casuta1_y+80*4,eax,112
jmp afisare_litere
button30_1:
scrie_cifra var_x,var_y,casuta1_x+80*5,casuta1_y+80*4,eax,116
jmp afisare_litere

linie6_1:
cmp var_x, casuta1_x+80
jl button31_1
cmp var_x, casuta1_x+80*2
jl button32_1
cmp var_x, casuta1_x+80*3
jl button33_1
cmp var_x, casuta1_x+80*4
jl button34_1
cmp var_x, casuta1_x+80*5
jl button35_1
cmp var_x, casuta1_x+80*6
jl button36_1

button31_1:
scrie_cifra var_x,var_y,casuta1_x,casuta1_y+80*5,eax,120 
jmp afisare_litere
button32_1:
scrie_cifra var_x,var_y,casuta1_x+80,casuta1_y+80*5,eax,124
jmp afisare_litere
button33_1:
scrie_cifra var_x,var_y,casuta1_x+80*2,casuta1_y+80*5,eax,128
jmp afisare_litere
button34_1:
scrie_cifra var_x,var_y,casuta1_x+80*3,casuta1_y+80*5,eax,132
jmp afisare_litere
button35_1:
scrie_cifra var_x,var_y,casuta1_x+80*4,casuta1_y+80*5,eax,136
jmp afisare_litere
button36_1:
scrie_cifra var_x,var_y,casuta1_x+80*5,casuta1_y+80*5,eax,140
jmp afisare_litere

evt_click:
;aici vedem daca s-a apasat butonul de verificare si in caz pozitiv incepem verificarea
mov eax, [ebp+arg2]
cmp eax, 850
jl ajutor
cmp eax, 940
jg ajutor
mov eax, [ebp+arg3]
cmp eax, 340
jl ajutor
cmp eax, 370
jg ajutor 

;adunari
mov eax, 0
add eax, matrice_introdusa[0*4]
add eax, matrice_introdusa[6*4]
cmp eax, 11
jne gresit;1

xor eax,eax
add eax, matrice_introdusa[30*4]
add eax, matrice_introdusa[31*4]
add eax, matrice_introdusa[32*4]
cmp eax, 8
jne gresit;2

xor eax, eax
add eax, matrice_introdusa[21*4]
add eax, matrice_introdusa[27*4]
add eax, matrice_introdusa[28*4]
cmp eax, 7
jne gresit;3

xor eax, eax
add eax, matrice_introdusa[29*4]
add eax, matrice_introdusa[35*4]
cmp eax, 9
jne gresit;4

;inmultiri
xor eax, eax
mov eax, matrice_introdusa[3*4]
mul matrice_introdusa[9*4]
cmp eax, 20
jne gresit;5

xor eax, eax
mov eax, matrice_introdusa[4*4]
mul matrice_introdusa[5*4]
mul matrice_introdusa[11*4]
mul matrice_introdusa[17*4]
cmp eax, 6
jne gresit;6

xor eax, eax
mov eax, matrice_introdusa[12*4]
mul matrice_introdusa[13*4]
mul matrice_introdusa[18*4]
mul matrice_introdusa[19*4]
cmp eax, 240
jne gresit;7

xor eax, eax
mov eax, matrice_introdusa[14*4]
mul matrice_introdusa[15*4]
cmp eax, 6
jne gresit;8

xor eax, eax
mov eax,matrice_introdusa[20*4]
mul matrice_introdusa[26*4]
cmp eax, 6
jne gresit;9

xor eax, eax
mov eax,matrice_introdusa[22*4]
mul matrice_introdusa[23*4]
cmp eax, 30
jne gresit;10

xor eax, eax
mov eax, matrice_introdusa[24*4]
mul matrice_introdusa[25*4]
cmp eax, 6
jne gresit;11



;scaderi
xor eax, eax
mov eax, matrice_introdusa[8*4]
sub eax, matrice_introdusa[7*4]
cmp eax, 3
jne gresit;12

;impartiri
xor eax, eax
mov eax, matrice_introdusa[2*4]
mov ebx,2
mul ebx
cmp matrice_introdusa[1*4],eax
jne gresit;13

xor eax, eax
mov eax, matrice_introdusa[4*10]
mov ebx,3
mul ebx
cmp matrice_introdusa[4*16], eax
jne gresit;14


xor eax, eax
mov eax, matrice_introdusa[34*4]
mov ebx, 2
mul ebx
cmp matrice_introdusa[33*4],eax
jne gresit;15

mov ecx, 35
verificare_intreg:
mov eax, matrice_introdusa[ecx*4]
cmp eax,matrice_raspunsuri[ecx*4]
jne gresit
loop verificare_intreg

;15 chenare
	 
	make_text_macro 'C', area, 855, 375
	make_text_macro 'O', area, 865, 375
	make_text_macro 'R', area, 875, 375
	make_text_macro 'E', area, 885, 375
	make_text_macro 'C', area, 895, 375
	make_text_macro 'T', area, 905, 375
	jmp afisare_litere
gresit:
	make_text_macro 'G', area, 855, 375
	make_text_macro 'R', area, 865, 375
	make_text_macro 'E', area, 875, 375
	make_text_macro 'S', area, 885, 375
	make_text_macro 'I', area, 895, 375
	make_text_macro 'T', area, 905, 375
jmp afisare_litere

;daca s-a apasat butonul de ajutor cautam casutele gresite
ajutor:
mov eax, [ebp+arg2]
cmp eax, 1050
jl chenar
cmp eax, 1120
jg chenar
mov eax, [ebp+arg3]
cmp eax, 340
jl chenar
cmp eax, 370
jg chenar

mov eax,matrice_raspunsuri[0*4]
cmp matrice_introdusa[0*4],eax
je casuta2
make_text_macro 'F' ,area, 290,180

casuta2:
mov eax,matrice_raspunsuri[1*4]
cmp matrice_introdusa[1*4],eax
je casuta3

make_text_macro 'F' ,area, 370,180


casuta3:
mov eax,matrice_raspunsuri[2*4]
cmp matrice_introdusa[2*4],eax
je casuta4

make_text_macro 'F' ,area, 450,180


casuta4:
mov eax,matrice_raspunsuri[3*4]
cmp matrice_introdusa[3*4],eax
je casuta5

make_text_macro 'F' ,area, 530,180
 

casuta5:
mov eax,matrice_raspunsuri[4*4]
cmp matrice_introdusa[4*4],eax
je casuta6

make_text_macro 'F' ,area, 610,180
 

casuta6:
mov eax,matrice_raspunsuri[5*4]
cmp matrice_introdusa[5*4],eax
je casuta7

make_text_macro 'F' ,area, 690,180
 

casuta7:
mov eax,matrice_raspunsuri[6*4]
cmp matrice_introdusa[6*4],eax
je casuta8

make_text_macro 'F' ,area, 290,260
 

casuta8:
mov eax,matrice_raspunsuri[7*4]
cmp matrice_introdusa[7*4],eax
je casuta9

make_text_macro 'F' ,area, 370,260
 

casuta9:
mov eax,matrice_raspunsuri[8*4]
cmp matrice_introdusa[8*4],eax
je casuta10

make_text_macro 'F' ,area, 450,260
 

casuta10:
mov eax,matrice_raspunsuri[9*4]
cmp matrice_introdusa[9*4],eax
je casuta11

make_text_macro 'F' ,area, 530,260
 

casuta11:
mov eax,matrice_raspunsuri[10*4]
cmp matrice_introdusa[10*4],eax
je casuta12

make_text_macro 'F' ,area, 610,260
 

casuta12:
mov eax,matrice_raspunsuri[11*4]
cmp matrice_introdusa[11*4],eax
je casuta13

make_text_macro 'F' ,area, 690,260
 

casuta13:
mov eax,matrice_raspunsuri[12*4]
cmp matrice_introdusa[12*4],eax
je casuta14

make_text_macro 'F' ,area, 290,340
 

casuta14:
mov eax,matrice_raspunsuri[13*4]
cmp matrice_introdusa[13*4],eax
je casuta15

make_text_macro 'F' ,area, 370,340
 

casuta15:
mov eax,matrice_raspunsuri[14*4]
cmp matrice_introdusa[14*4],eax
je casuta16

make_text_macro 'F' ,area, 450,340

casuta16:
mov eax,matrice_raspunsuri[15*4]
cmp matrice_introdusa[15*4],eax
je casuta17

make_text_macro 'F' ,area, 530,340
 

casuta17:
mov eax,matrice_raspunsuri[16*4]
cmp matrice_introdusa[16*4],eax
je casuta18

make_text_macro 'F' ,area, 610,340
 

casuta18:
mov eax,matrice_raspunsuri[17*4]
cmp matrice_introdusa[17*4],eax
je casuta19

make_text_macro 'F' ,area, 690,340
 

casuta19:
mov eax,matrice_raspunsuri[18*4]
cmp matrice_introdusa[18*4],eax
je casuta20

make_text_macro 'F' ,area, 290,420
 

casuta20:
mov eax,matrice_raspunsuri[19*4]
cmp matrice_introdusa[19*4],eax
je casuta21

make_text_macro 'F' ,area, 370,420
 

casuta21:
mov eax,matrice_raspunsuri[20*4]
cmp matrice_introdusa[20*4],eax
je casuta22

make_text_macro 'F' ,area, 450,420
 

casuta22:
mov eax,matrice_raspunsuri[21*4]
cmp matrice_introdusa[21*4],eax
je casuta23

make_text_macro 'F' ,area, 530,420
 

casuta23:
mov eax,matrice_raspunsuri[22*4]
cmp matrice_introdusa[22*4],eax
je casuta24

make_text_macro 'F' ,area, 610,420
 

casuta24:
mov eax,matrice_raspunsuri[23*4]
cmp matrice_introdusa[23*4],eax
je casuta25

make_text_macro 'F' ,area, 690,420
 

casuta25:
mov eax,matrice_raspunsuri[24*4]
cmp matrice_introdusa[24*4],eax
je casuta26

make_text_macro 'F' ,area, 290,500
 

casuta26:
mov eax,matrice_raspunsuri[25*4]
cmp matrice_introdusa[25*4],eax
je casuta27

make_text_macro 'F' ,area, 370,500
 

casuta27:
mov eax,matrice_raspunsuri[26*4]
cmp matrice_introdusa[26*4],eax
je casuta28

make_text_macro 'F' ,area, 450,500
 

casuta28:
mov eax,matrice_raspunsuri[27*4]
cmp matrice_introdusa[27*4],eax
je casuta29

make_text_macro 'F' ,area, 530,500
 

casuta29:
mov eax,matrice_raspunsuri[28*4]
cmp matrice_introdusa[28*4],eax
je casuta30

make_text_macro 'F' ,area, 610,500
 

casuta30:
mov eax,matrice_raspunsuri[29*4]
cmp matrice_introdusa[29*4],eax
je casuta31

make_text_macro 'F' ,area, 690,500
 

casuta31:
mov eax,matrice_raspunsuri[30*4]
cmp matrice_introdusa[30*4],eax
je casuta32

make_text_macro 'F' ,area, 290,580
 

casuta32:
mov eax,matrice_raspunsuri[31*4]
cmp matrice_introdusa[31*4],eax
je casuta33

make_text_macro 'F' ,area, 370,580
 


casuta33:
mov eax,matrice_raspunsuri[32*4]
cmp matrice_introdusa[32*4],eax
je casuta34

make_text_macro 'F' ,area, 450,580
 

casuta34:
mov eax,matrice_raspunsuri[33*4]
cmp matrice_introdusa[33*4],eax
je casuta35

make_text_macro 'F' ,area, 530,580
 

casuta35:
mov eax,matrice_raspunsuri[34*4]
cmp matrice_introdusa[34*4],eax
je casuta36

make_text_macro 'F' ,area, 610,580
 

casuta36:
mov eax,matrice_raspunsuri[35*4]
cmp matrice_introdusa[35*4],eax
je afisare_litere
make_text_macro 'F' ,area, 690,580
jmp afisare_litere




chenar:
make_text_macro ' ' ,area, 290,180
make_text_macro ' ' ,area, 370,180
make_text_macro ' ' ,area, 450,180
make_text_macro ' ' ,area, 530,180
make_text_macro ' ' ,area, 610,180
make_text_macro ' ' ,area, 690,180
make_text_macro ' ' ,area, 290,260
make_text_macro ' ' ,area, 370,260
make_text_macro ' ' ,area, 450,260
make_text_macro ' ' ,area, 530,260
make_text_macro ' ' ,area, 610,260
make_text_macro ' ' ,area, 690,260
make_text_macro ' ' ,area, 290,340
make_text_macro ' ' ,area, 370,340
make_text_macro ' ' ,area, 450,340
make_text_macro ' ' ,area, 530,340
make_text_macro ' ' ,area, 610,340
make_text_macro ' ' ,area, 690,340
make_text_macro ' ' ,area, 290,420
make_text_macro ' ' ,area, 370,420
make_text_macro ' ' ,area, 450,420
make_text_macro ' ' ,area, 530,420
make_text_macro ' ' ,area, 610,420
make_text_macro ' ' ,area, 690,420
make_text_macro ' ' ,area, 290,500
make_text_macro ' ' ,area, 370,500
make_text_macro ' ' ,area, 450,500
make_text_macro ' ' ,area, 530,500
make_text_macro ' ' ,area, 610,500
make_text_macro ' ' ,area, 690,500
make_text_macro ' ' ,area, 290,580
make_text_macro ' ' ,area, 370,580
make_text_macro ' ' ,area, 450,580
make_text_macro ' ' ,area, 530,580
make_text_macro ' ' ,area, 610,580
make_text_macro ' ' ,area, 690,580
;verificam linia pe care ne aflam
	make_text_macro ' ', area, 855, 375
	make_text_macro ' ', area, 865, 375
	make_text_macro ' ', area, 875, 375
	make_text_macro ' ', area, 885, 375
	make_text_macro ' ', area, 895, 375
	make_text_macro ' ', area, 905, 375
mov eax, [ebp+arg2]
cmp eax, 250
jl afisare_litere
cmp eax, 740
jg afisare_litere
mov eax, [ebp+arg3]
cmp eax, 150
jl afisare_litere
cmp eax, 640
jg afisare_litere
cmp eax, casuta1_y+80
jl linie1
 cmp eax, casuta1_y+80*2
 jl linie2
 cmp eax, casuta1_y+80*3
 jl linie3
 cmp eax, casuta1_y+80*4
 jl linie4
 cmp eax, casuta1_y+80*5
 jl linie5
 cmp eax, casuta1_y+80*6
 jl linie6
;verificam in care patrat ne aflam
linie1:
mov eax, [ebp+arg2]
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80
jl button1
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*2
jl button2
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*3
jl button3
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*4
jl button4
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*5
jl button5
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*6
jl button6
button_fail casuta1_x,casuta1_y

button1:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x,casuta1_y
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button2:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80,casuta1_y
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button3:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*2,casuta1_y
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button4:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*3,casuta1_y
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button5:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*4,casuta1_y
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button6:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*5,casuta1_y
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

linie2:
mov eax, [ebp+arg2]
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80
jl button7
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*2
jl button8
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*3
jl button9
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*4
jl button10
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*5
jl button11
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*6
jl button12
button_fail casuta1_x,casuta1_y


button7:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x,casuta1_y+80
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
 jmp afisare_litere
button8:

scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80,casuta1_y+80
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere
button9:

scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*2,casuta1_y+80
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere
button10:

scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*3,casuta1_y+80
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button11:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*4,casuta1_y+80
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button12:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*5,casuta1_y+80
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere


linie3:
mov eax, [ebp+arg2]
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80
jl button13

button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*2
jl button14
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*3
jl button15
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*4
jl button16
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*5
jl button17
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*6
jl button18
button_fail casuta1_x,casuta1_y


button13:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x,casuta1_y+80*2
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
 jmp afisare_litere
 
button14:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80,casuta1_y+80*2
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button15:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*2,casuta1_y+80*2
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button16:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*3,casuta1_y+80*2
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button17:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*4,casuta1_y+80*2
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button18:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*5,casuta1_y+80*2
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

linie4:
mov eax, [ebp+arg2]
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80
jl button19
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*2
jl button20
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*3
jl button21
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*4
jl button22
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*5
jl button23
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*6
jl button24
button_fail casuta1_x,casuta1_y
 

button19:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x,casuta1_y+80*3
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
 jmp afisare_litere
 
button20:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80,casuta1_y+80*3
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button21:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*2,casuta1_y+80*3
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button22:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*3,casuta1_y+80*3
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button23:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*4,casuta1_y+80*3
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button24:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*5,casuta1_y+80*3
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

linie5:
mov eax, [ebp+arg2]
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80
jl button25
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*2
jl button26
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*3
jl button27
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*4
jl button28
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*5
jl button29
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*6
jl button30
button_fail casuta1_x,casuta1_y


button25:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x,casuta1_y+80*4
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
 jmp afisare_litere
 
button26:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80,casuta1_y+80*4
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button27:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*2,casuta1_y+80*4
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button28:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*3,casuta1_y+80*4
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button29:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*4,casuta1_y+80*4
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button30:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*5,casuta1_y+80*4
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

linie6:
mov eax, [ebp+arg2]
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80
jl button31
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*2
jl button32
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*3
jl button33
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*4
jl button34
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*5
jl button35
button_fail casuta1_x,casuta1_y
cmp eax, casuta1_x+80*6
jl button36
button_fail casuta1_x,casuta1_y


button31:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x,casuta1_y+80*5
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
 jmp afisare_litere
 
button32:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80,casuta1_y+80*5
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button33:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*2,casuta1_y+80*5
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button34:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*3,casuta1_y+80*5
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button35:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*4,casuta1_y+80*5
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

button36:
scrie_pozitionare [ebp+arg2],[ebp+arg3],casuta1_x+80*5,casuta1_y+80*5
mov eax, [ebp+arg2]
mov var_x, eax
mov eax, [ebp+arg3]
mov var_y, eax
jmp afisare_litere

evt_timer:
	inc counter
	
afisare_litere:
	;afisam valoarea counter-ului curent (sute, zeci si unitati)
	mov ebx, 10
	mov eax, counter
	;cifra unitatilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 30, 10
	;cifra zecilor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 10
	;cifra sutelor
	mov edx, 0
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 10
	
	;scriem un mesaj
	
	make_text_macro 'K', area, 410, 100
	make_text_macro 'E', area, 420, 100
	make_text_macro 'N', area, 430, 100
	make_text_macro ' ', area, 440, 100
	make_text_macro 'K', area, 450, 100
	make_text_macro 'E', area, 460, 100
	make_text_macro 'N', area, 470, 100
	make_text_macro ' ', area, 480, 100
	make_text_macro 'G', area, 490, 100
	make_text_macro 'A', area, 500, 100
	make_text_macro 'M', area, 510, 100
	make_text_macro 'E', area, 520, 100
	
	make_text_macro '1', area, 260, 155
	make_text_macro '1', area, 270, 155
	
	make_text_macro '2', area, 340, 155
	
	make_text_macro '2', area, 500, 155
	make_text_macro '0', area, 510, 155
	
	make_text_macro '6', area, 580, 155
	
	make_text_macro '3', area, 340, 235
	
	make_text_macro '3', area, 580, 235
	
	make_text_macro '2', area, 260, 315
	make_text_macro '4', area, 270, 315
	make_text_macro '0', area, 280, 315
	
	make_text_macro '6', area, 420, 315
	
	make_text_macro '6', area, 420, 395
	
	make_text_macro '7', area, 500, 395
	
	make_text_macro '3', area, 580, 395
	make_text_macro '0', area, 590, 395
	
	make_text_macro '6', area, 260, 475
	
	make_text_macro '9', area, 660, 475
	
	make_text_macro '8', area, 260, 555
	
	make_text_macro '2', area, 500, 555
	
	
	make_text_macro 'V', area, 855, 345
	make_text_macro 'E', area, 865, 345
	make_text_macro 'R', area, 875, 345
	make_text_macro 'I', area, 885, 345
	make_text_macro 'F', area, 895, 345
	make_text_macro 'I', area, 905, 345
	make_text_macro 'C', area, 915, 345
	make_text_macro 'A', area, 925, 345
	
	
	line_horizontal 850,340,90,0
	line_horizontal 850,370,90,0
	line_vertical 850,340,30,0
	line_vertical 940,340,30,0
	
	make_text_macro 'A', area, 1055, 345
	make_text_macro 'J', area, 1065, 345
	make_text_macro 'U', area, 1075, 345
	make_text_macro 'T', area, 1085, 345
	make_text_macro 'O', area, 1095, 345
	make_text_macro 'R', area, 1105, 345
	
	line_horizontal 1050,340,70,0
	line_horizontal 1050,370,70,0
	line_vertical 1050,340,30,0
	line_vertical 1120,340,30,0
	
	;desenam plus
	line_horizontal 280, 165, 10, 0
	line_vertical 285, 160, 10, 0
	
	line_horizontal 512, 407, 10, 0
	line_vertical 517, 402, 10, 0
	
	line_horizontal 672, 487, 10, 0
	line_vertical 677, 482, 10, 0
	
	line_horizontal 272, 567, 10, 0
	line_vertical 277, 562, 10, 0
	;desenam minus
	line_horizontal 351, 245, 10, 0
	
	
	;desenam impartire
	line_horizontal 354, 160, 4, 0
	line_horizontal 354, 161, 4, 0
	line_horizontal 354, 162, 4, 0
	line_horizontal 351, 165, 10, 0
	line_horizontal 354, 168, 4, 0
	line_horizontal 354, 169, 4, 0
	line_horizontal 354, 170, 4, 0
	
	line_horizontal 594, 240, 4, 0
	line_horizontal 594, 241, 4, 0
	line_horizontal 594, 242, 4, 0
	line_horizontal 591, 245, 10, 0
	line_horizontal 594, 248, 4, 0
	line_horizontal 594, 249, 4, 0
	line_horizontal 594, 250, 4, 0
	
	line_horizontal 514, 560, 4, 0
	line_horizontal 514, 561, 4, 0
	line_horizontal 514, 562, 4, 0
	line_horizontal 511, 565, 10, 0
	line_horizontal 514, 568, 4, 0
	line_horizontal 514, 569, 4, 0
	line_horizontal 514, 570, 4, 0
	;desenam inmultire
	line_oblique_r 522,162,10,0
	line_oblique_r 523,162,10,0
	line_oblique_l 532,162,10,0
	line_oblique_l 531,162,10,0
	
	line_oblique_r 592,162,10,0
	line_oblique_r 593,162,10,0
	line_oblique_l 602,162,10,0
	line_oblique_l 601,162,10,0
	
	line_oblique_r 292,322,10,0
	line_oblique_r 293,322,10,0
	line_oblique_l 302,322,10,0
	line_oblique_l 301,322,10,0
	
	line_oblique_r 432,322,10,0
	line_oblique_r 433,322,10,0
	line_oblique_l 442,322,10,0
	line_oblique_l 441,322,10,0
	
	line_oblique_r 432,402,10,0
	line_oblique_r 433,402,10,0
	line_oblique_l 442,402,10,0
	line_oblique_l 441,402,10,0
	
	line_oblique_r 602,402,10,0
	line_oblique_r 603,402,10,0
	line_oblique_l 612,402,10,0
	line_oblique_l 611,402,10,0
	
	line_oblique_r 272,482,10,0
	line_oblique_r 273,482,10,0
	line_oblique_l 282,482,10,0
	line_oblique_l 281,482,10,0
	line_horizontal button_x,button_y,button_size_celula*6,0
	line_horizontal button_x,button_y+button_size_celula*6,button_size_celula*6,0
	line_vertical button_x,button_y,button_size_celula*6,0
	line_vertical button_x+button_size_celula*6,button_y,button_size_celula*6,0
	
	line_horizontal button_x,button_y+button_size_celula,button_size_celula*6,0
	line_horizontal button_x,button_y+button_size_celula*2,button_size_celula*6,0
	line_horizontal button_x,button_y+button_size_celula*3,button_size_celula*6,0
	line_horizontal button_x,button_y+button_size_celula*4,button_size_celula*6,0
	line_horizontal button_x,button_y+button_size_celula*5,button_size_celula*6,0
	line_horizontal button_x,button_y+button_size_celula*6,button_size_celula*6,0
	line_vertical button_x+button_size_celula,button_y,button_size_celula*6,0
	line_vertical button_x+button_size_celula*2,button_y,button_size_celula*6,0
	line_vertical button_x+button_size_celula*3,button_y,button_size_celula*6,0
	line_vertical button_x+button_size_celula*4,button_y,button_size_celula*6,0
	line_vertical button_x+button_size_celula*5,button_y,button_size_celula*6,0
	line_vertical button_x+button_size_celula*6,button_y,button_size_celula*6,0
	 ;pana aici am creat tabela de 6*6, iar de acum urmeaza sa cream "grupele"
	 line_vertical button_x+1,button_y,button_size_celula*6,0
	 line_vertical button_x+1+button_size_celula*6,button_y,button_size_celula*6,0
	 line_horizontal button_x,button_y+1,button_size_celula*6,0
	 line_horizontal button_x,button_y+1+button_size_celula*6,button_size_celula*6,0
	 line_vertical button_x+1+button_size_celula,button_y,button_size_celula*2,0
	 line_vertical button_x+1+button_size_celula*3,button_y,button_size_celula*2,0
	 line_vertical button_x+1+button_size_celula*4,button_y,button_size_celula*4,0
	 line_vertical button_x+1+button_size_celula*5,button_y+button_size_celula,button_size_celula*2,0
	 line_vertical button_x+1+button_size_celula*5,button_y+button_size_celula*4,button_size_celula*2,0
	 line_vertical button_x+1+button_size_celula*2,button_y+button_size_celula*2,button_size_celula*3,0
	 line_vertical button_x+1+button_size_celula*3,button_y+button_size_celula*3,button_size_celula*3,0
	 line_horizontal button_x+button_size_celula,button_y+1+button_size_celula,button_size_celula*2,0
	 line_horizontal button_x+button_size_celula*4,button_y+1+button_size_celula,button_size_celula,0
	 line_horizontal button_x,button_y+1+button_size_celula*2,button_size_celula*4,0
	 line_horizontal button_x+button_size_celula*2,button_y+1+button_size_celula*3,button_size_celula*4,0
	 line_horizontal button_x,button_y+1+button_size_celula*4,button_size_celula*2,0
	 line_horizontal button_x+button_size_celula*4,button_y+1+button_size_celula*4,button_size_celula*2,0
	 line_horizontal button_x,button_y+1+button_size_celula*5,button_size_celula*5,0
	
	line_vertical button_x+2,button_y,button_size_celula*6,0
	 line_vertical button_x+2+button_size_celula*6,button_y,button_size_celula*6,0
	 line_horizontal button_x,button_y+2,button_size_celula*6,0
	 line_horizontal button_x,button_y+2+button_size_celula*6,button_size_celula*6,0
	 line_vertical button_x+2+button_size_celula,button_y,button_size_celula*2,0
	 line_vertical button_x+2+button_size_celula*3,button_y,button_size_celula*2,0
	 line_vertical button_x+2+button_size_celula*4,button_y,button_size_celula*4,0
	 line_vertical button_x+2+button_size_celula*5,button_y+button_size_celula,button_size_celula*2,0
	 line_vertical button_x+2+button_size_celula*5,button_y+button_size_celula*4,button_size_celula*2,0
	 line_vertical button_x+2+button_size_celula*2,button_y+button_size_celula*2,button_size_celula*3,0
	 line_vertical button_x+2+button_size_celula*3,button_y+button_size_celula*3,button_size_celula*3,0
	 line_horizontal button_x+button_size_celula,button_y+2+button_size_celula,button_size_celula*2,0
	 line_horizontal button_x+button_size_celula*4,button_y+2+button_size_celula,button_size_celula,0
	 line_horizontal button_x,button_y+2+button_size_celula*2,button_size_celula*4,0
	 line_horizontal button_x+button_size_celula*2,button_y+2+button_size_celula*3,button_size_celula*4,0
	 line_horizontal button_x,button_y+2+button_size_celula*4,button_size_celula*2,0
	 line_horizontal button_x+button_size_celula*4,button_y+2+button_size_celula*4,button_size_celula*2,0
	 line_horizontal button_x,button_y+2+button_size_celula*5,button_size_celula*5,0
	 
	

final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
