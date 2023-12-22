#!/usr/bin/perl


$file=$ARGV[0];
chomp($file);

$fileo=$ARGV[1];
chomp($fileo);

open(FO,">$fileo");
open(FI,"$file");
while($line=<FI>){
	chomp($line);
	if(index($line,">")==0){
		$subline = substr($line,1,length($line)-1);
	}
	else{
		print FO "$subline\t$line\n";
	}
}
close FI;
close FO;


