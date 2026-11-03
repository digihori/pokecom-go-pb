#!/usr/bin/perl
use strict;
use warnings;

my @code = (
  " ", "+", "-", "*", "/", "\\UA", "!", "\"", "#", "\$", ">", "\\GE", "=", "\\LE", "<", "\\NE",
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "\\PI", ")", "(", "\\EM", "\\EX",
  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P",
  "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "", "", "", "", "", "",
  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
  "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "", "", "?", ",", ";", ":",
  "\\CI", "\\SG", "\\DG", "\\TR", "\@", "\\CR", "\\DV", "\\SP", "\\LA", "\\HT", "\\DI", "\\CL", "\\MU", "\\OM", "\\DA", "\\RA",
  "%", "\\", "\\SQ", "[", "&", "_", "\'", "\\DT", "]", "\\BX", "", "", "", "", "", "",

  "SIN", "COS", "TAN", "ASN", "ACS", "ATN", "LOG", "LN", "EXP", "SQR", "INT", "FRAC", "ABS", "SGN", "RND", "RAN#",
  "LEN\\(", "VAL\\(", "MID\\(", "KEY", "CSR", "TO", "STEP", "THEN", "", "", "", "", "", "", "", "",
  "FOR", "NEXT", "GOTO", "GOSUB", "RETURN", "IF", "PRINT", "INPUT", "MODE", "STOP", "END", "", "", "", "", "",
  "VAC", "SET", "PUT", "GET", "", "", "", "", "", "", "", "", "", "", "", "",
  "DEFM", "SAVE", "LOAD", "VER", "LIST", "RUN", "CLEAR", "", "", "", "", "", "", "", "", "",
  "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
  "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
  "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""
);



#
#   START
#

#print $#ARGV."\n";
printf STDERR "\npbsavea.pl (PocketBasic to WAV) version 0.5\n";
# 0.5 '^','\\'が正しくエンコードできない不具合を修正した
# 0.4 '^'が正しくエンコードできない不具合を修正した
# 0.3 ファイル名が8文字を超えたときに正しくファイルが作れない不具合を修正した
# 0.2 最初の公開バージョン
# 0.1 初版
die "usage: perl pbsavea.pl <infile.bas> <outfile.wav>\n" if ($#ARGV!=1);

my $wavfile = "";
my $infile = "";
while ( $_=shift @ARGV ) {
    if ($_=~/^.*\.wav/i) {
		$wavfile=$_;
		next;
    }
    if ($_=~/^.*\.bas/i) {
		$infile=$_;
		next;
    }
    die "usage: perl pbsavea.pl <infile.bas> <outfile.wav>\n";
}

open(WAV, "> $wavfile") or die "ERROR: cannot create wav file \"$wavfile\".\n";
binmode WAV;

open(SOURCE, "< $infile") or die "ERROR: cannot open file \"$infile\".\n";

my $bank=0;
my(@dump) = ();
my $p = 0;
my $linenum_top = 0;
my $linenum_top0;
my $linenum_top1;

$dump[$p++] = 0x02;		# start mark
LOOP: while (<SOURCE>) {
	chomp;
	my $linenum = 0;

	#print $_;
	# 空行は読み捨てる
	if ($_ eq "") {
		next;
	}

	if ($_ =~ /^\[P[0-9]\]/) {
		# ページ指定
		my $last = $bank;
		$bank=substr($_, 2, 1);
		if ($last != $bank) {
			for (my $i = $last; $i < $bank; $i++) {
				printf "--- separater(%d) ---\n", $i;
				$dump[$p++] = 0xe0;		# program separater
			}
		}
		printf "[P=%d]\n", $bank;
		$linenum = 0;
	} else {
		# 通常の行
		my @token = ($_ =~ /(?:^[0-9]+:?)|(?:REM.*$)|(?:"[^"]*")|(?:[^ "]+)/g);
		my $len = @token;
		for (my $i = 0; $i < $len; $i++) {
			#printf "[%d]", $i;
			#printf "%s\n", $token[$i];
			if ($token[$i] =~ /^"|^REM/) {
				# printf "ダブルコーテーション文字列の処理\n";
				if ($linenum == 0) {
					next;
				}
				printf "'%s'\n", $token[$i];
				my $l = length($token[$i]);
				for (my $j = 0; $j < $l; $j++) {
					my $c = substr($token[$i], $j, 1);
					if ($c eq "\\") {
						if ($j+1 < $l && substr($token[$i], $j+1, 1) eq "\\") {
							$dump[$p++] = 0x71;	# '\\'
							$j++;
						} elsif ($j+2 < $l) {
							my $tmp = substr($token[$i], $j, 3);
							$dump[$p++] = getInternalCode($tmp);
							$j+=2;
						}
					} elsif ($c eq '^') {
						$dump[$p++] = 0x05;	# '^' -> '↑'
					} else {
						$dump[$p++] = getInternalCode($c);
					}
					printf "%02x\n", $dump[$p-1];
				}
			} else {
				my $tmp = $token[$i];
				$tmp =~ s/>=/\\GE/g;
				$tmp =~ s/<=/\\LE/g;
				$tmp =~ s/<>/\\NE/g;
				$tmp =~ s/!=/\\NE/g;
				my @token1 = split(/\s+|(?<=\\GE|\\LE|\\NE|\\UA)|(?=\\GE|\\LE|\\NE|\\UA)|(?<=[\*\/\+\-><=:;,\(\)])|(?=[\*\/\+\-><=:;,\)])/, $tmp);
				my $length1 = @token1;
				my $j = 0;
				if ($linenum == 0) {
					if ($token1[0] =~ /^[0-9]+$/ && 1 <= $token1[0] && $token1[0] <= 9999) {
						$linenum = $token1[0];
						print "linenum=".$token1[0]."\n";
						$j++;
						if ($length1 > 1 && $token1[1] eq ":") {
							#print "skipped ':'\n";
							$j++;	# 行番号の次が:（コロン）の場合は読み捨て
						}
						my $l0 = $linenum % 100;
						$l0 = int($l0 / 10) * 0x10 + $l0 % 10;
						#printf "%02x ", $l0;
						$dump[$p++] = $l0;
						my $l1 = int($linenum / 100);
						$l1 = int($l1 / 10) * 0x10 + $l1 % 10;
						$dump[$p++] = $l1;
						#printf "%02x\n", $l1;
						if ($linenum_top == 0) {
							$linenum_top = $linenum;	# 先頭の行番号を覚えておく
							$linenum_top0 = $l0;
							$linenum_top1 = $l1;
						}
					} else {
						printf "skipped '%s'\n", $token[$i];
						next LOOP;	# 先頭に行番号がない場合は読み捨て
					}
				}
				for (; $j < $length1; $j++) {
					printf "'%s'\n", $token1[$j];
					printInternalCode($token1[$j]);
				}
			}
		}
		$dump[$p++] = 0xff;		# 行区切りコード
	}

}

for (my $i = $bank; $i <= 9; $i++) {
	printf "--- separater(%d) ---\n", $i;
	$dump[$p++] = 0xe0;		# program separater
}
$dump[$p++] = 0xf0;		# end mark
$dump[$p++] = 0x00;		# EOF

BinaryDump(@dump);


#
# wavout
#
my $datalen = @dump;
printf "datalen = %d\n", $datalen;

my $wl = 0x400*72 + 11*12*72 + 0x400*72 + $datalen*12*72;
        # lead + data(filename,etc) + lead + data(body)
my $w1="\xff\xff\xff\xff\xff\x00\x00\x00\x00";
$w1=$w1.$w1.$w1.$w1.$w1.$w1.$w1.$w1;
my $w0="\xff\xff\xff\xff\xff\xff\xff\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00\x00";
$w0=$w0.$w0.$w0.$w0;

print WAV "RIFF";
$wl = $wl +44-4;		# all(header:44+$wl) - 4
printf WAV "%c%c%c%c",$wl&0xff,($wl>>8)&0xff,($wl>>16)&0xff,($wl>>24)&0xff;
$wl = $wl -44+4;
print WAV "WAVEfmt ";
print WAV "\x10\x00\x00\x00";
print WAV "\x01\x00";		# PCM
print WAV "\x01\x00";		# mono
print WAV "\x22\x56\x00\x00";	# sampling freq. = 22,050 Hz
print WAV "\x22\x56\x00\x00";	# byte / sec.
print WAV "\x01\x00";		# byte / sample x channel
print WAV "\x08\x00";		# bit / sample
print WAV "data";
printf WAV "%c%c%c%c",$wl&0xff,($wl>>8)&0xff,($wl>>16)&0xff,($wl>>24)&0xff;	# data length

for (my $i = 0; $i < 0x400; $i++ ){
	print WAV $w1;
}

my $fname = $infile;
$fname =~ s/\..*$//g;
my $flen = length($fname);
printf "filename=%s(%d)\n", $fname, $flen;
write1byte(0xf0 + ($flen > 8 ? 8 : $flen));
for (my $i = 0; $i < 8; $i++) {
	if ($i < $flen) {
		write1byte(getInternalCode(substr($infile, $i, 1)));
	} else {
		write1byte(0);
	}
}
write1byte($linenum_top0);
write1byte($linenum_top1);

for(my $i = 0; $i < 0x400; $i++ ){
	print WAV $w1;
}

for (my $i = 0; $i < $datalen; $i++) {
	write1byte($dump[$i]);
}

print "complete.\n";
exit;



sub printInternalCode {
	my @code = splitEx($_[0]);
	my $l = @code;
	my $src;
	if ($l == 2) {
		$dump[$p++] = getReservFunctionCode($code[0]);
		printf "%02x\n", $dump[$p-1];
		$src = $code[1];
	} else {
		$src = $code[0];
	}
	for (my $i = 0; $i < length($src); $i++) {
		my $c = substr($src, $i, 1);
		if ($c eq "\\") {
			if ($i < length($src) - 1 && substr($src, $i+1, 1) eq "\\") {
				$dump[$p++] = 0x71;	# '\\'
				$i++;
			} elsif ($i < length($src) - 2) {
				my $tmp = substr($src, $i, 3);
				$dump[$p++] = getInternalCode($tmp);
				$i+=2;
			}
		} else {
			if ($c eq ":") {
				$dump[$p++] = 0xfe;		# statement delimiter
			} elsif ($c eq "^") {
				$dump[$p++] = 0x05;		# '^'->'↑'
			} else {
				$dump[$p++] = getInternalCode($c);
			}
		}
		printf "%02x\n", $dump[$p-1];
	}
}

sub getInternalCode {
	my $i;
	for ($i = 0x00; $i <= 0x7f; $i++) {
		if ($code[$i] eq "") {
			next;
		}
		if ($code[$i] eq $_[0]) {
			last;
		}
	}
	if ($i <= 0x7f) {
		return $i;	
	} else {
		return 0;
	}
}

sub getReservFunctionCode {
	my $i;
	for ($i = 0x80; $i <= 0xcf; $i++) {
		if ($code[$i] eq "") {
			next;
		}
		if ($code[$i] eq $_[0]) {
			last;
		}
	}
	return $i;
}

sub splitEx {
	my(@RETURN) = ();
	for (my $i = 0x80; $i < 0xcf; $i++) {
		#printf "%02x\n", $i;
		if ($code[$i] eq "") {
			next;
		}
		#printf "'%s' '%s'\n", $_[0], $code[$i];
		if ($_[0] =~ /^$code[$i]/) {
			# 予約語とそれ以外に分離する
			$RETURN[0] = $code[$i];
			$RETURN[1] = $_[0];
			$RETURN[1] =~ s/^$code[$i]//g;
			return @RETURN;
		}
	}
	$RETURN[0] = $_[0];
	return @RETURN;
}

sub BinaryDump {
    my $len = @_;
	my $i;
    for ($i = 0; $i < $len; $i++) {
        printf("%02X ", $_[$i]);
        if (($i % 16) == 15) {
            print "\n";
        }
    }
    if (($i % 16 + 1) != 15) {
        print "\n";
    }
	printf "total : %d byte\n", $len;
}

sub parity {
	my $p = 0;
	my $val = $_[0];
	for (my $i = 0; $i < 8; $i++) {
		if ($val & 0x01) {
			$p++;
		}
		$val >>= 1;
	}
	return ($p & 0x01);
}

sub write1byte {
	printf "%02x\n", $_[0];
	print WAV $w0;	# start bit
	$_[0] & 0x1 and print WAV $w1 or print WAV $w0;
	$_[0] & 0x2 and print WAV $w1 or print WAV $w0;
	$_[0] & 0x4 and print WAV $w1 or print WAV $w0;
	$_[0] & 0x8 and print WAV $w1 or print WAV $w0;
	$_[0] & 0x10 and print WAV $w1 or print WAV $w0;
	$_[0] & 0x20 and print WAV $w1 or print WAV $w0;
	$_[0] & 0x40 and print WAV $w1 or print WAV $w0;
	$_[0] & 0x80 and print WAV $w1 or print WAV $w0;
	parity($_[0]) and print WAV $w1 or print WAV $w0;	# parity(odd)
	print WAV $w1, $w1;	# stop bit 2
}

