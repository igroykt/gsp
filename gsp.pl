#!/usr/bin/perl

#################################################
# Google Store Parser v1.1                      #
# igroykt (c)29.09.2014		                #
#################################################

use strict;
use HTML::TreeBuilder::XPath;
use File::Copy qw(move);
use File::Copy qw(copy);
#use List::MoreUtils qw(uniq);
use Tie::File;
use MIME::Lite;
use MIME::Base64 ();
use Time::Piece;
no utf8;
use Switch;
use Data::Dumper;

#ENV
my $pwd="/root/bin/gsp";

#RU SETTINGS
my $ru_current=$pwd."/ru_current.txt";
my $ru_previous=$pwd."/ru_previous.txt";
my $ru_tmp=$pwd."/ru.tmp";
my $ru_mail=$pwd."/ru_mail.txt";
my $ru_url="";

#EN SETTINGS
my $en_current=$pwd."/en_current.txt";
my $en_previous=$pwd."/en_previous.txt";
my $en_tmp=$pwd."/en.tmp";
my $en_mail=$pwd."/en_mail.txt";
my $en_url="";

#MAIL SETTINGS
my $to='';
my $from='';
my $ru_subject='Google Store Reviews [RU]';
my $en_subject='Google Store Reviews [EN]';

sub trim {
        my($string)=@_;
        for ($string) {
                s/^\s+//;
                s/\s+$//;
        }
        $string=substr($string,0,-26);
        return $string;
}

sub parseReview{
        my $num_args=scalar(@_);
        my $getHTML=`lynx -dump -source '$_[0]' > $_[1]`;
        my $tree=HTML::TreeBuilder::XPath->new;
        $tree->parse_file($_[1]);
        my %seen=();
        my @authors=();
        my $fileHandler;
        my $date=localtime->strftime('%Y-%m-%d');
        for my $author($tree->findnodes(q{//div/span[@class="author-name"]})){
                push(@authors,$author->findvalue(q{./a}));
        }
        my @authors=grep{ ! $seen{ $_ }++ } @authors;

        my %seen=();
        my @comments=();
        my $fileHandler;
        for my $comment($tree->findnodes(q{//div[@class="review-body"]})){
                push(@comments,$comment->as_text);
        }
        my @comments=grep{ ! $seen{ $_ }++ } @comments;

        my $h={};
        @{$h}{@authors}=@comments;
        my $s=Dumper($h);
        $s=~ s/\$VAR1 = {//;
        $s=~ s/};//;
        $s=~ s/          '/Автор: /g;
        $s=~ s/' => '/ Комментарий: /g;
        $s=~ s/'//g;
        $s=~ s/,//g;
        $s=~ s/\s+$//g;
        $s=substr($s,1);
        open $fileHandler,'>',$_[2];
        print {$fileHandler} $s;
        close $fileHandler;
        $tree->delete;
        unlink $_[1];
}

sub normalizeText {
        my $num_args=scalar(@_);
        my $fileHandler;
        my @text=();
        open $fileHandler,'<',$_[0];
        while(my $line=<$fileHandler>){
                $line=~ s/Автор:  /Автор: Не указан /;
                $line=~ s/Комментарий:  /Комментарий: Не указан /;
                $line=~ s/Автор/\nАвтор/;
                $line=~ s/Комментарий/\nКомментарий/;
                push(@text,$line);
        }
        close $fileHandler;
        open $fileHandler,'>',$_[0];
        print {$fileHandler} @text;
        close $fileHandler;
}

sub makeUniq {
        my $num_args=scalar(@_);
        tie my @lines,'Tie::File',$_[0];
        my %seen=();
        @lines=grep { ! $seen{$_}++ } @lines;
}

sub sendMail {
        my $num_args=scalar(@_);
        if (-s $_[3]){
                my $DIFF=`diff -u $_[2] $_[3] |grep '-'|sed '1,3d'|sed 's/-//g'|grep -v '+'|sed '/Комментарий/G' > $_[1]`;
                makeUniq($_[1]);
                normalizeText($_[1]);
        }
        if (-z $_[1]){
                unlink $_[1];
        }
        if (-s $_[1]){
                open my $fileHandler,'<',$_[1] or die "Couldn't open $_[1]: $!";
                my $text=do {
                        local $/;
                        <$fileHandler>
                };
                close $fileHandler;
                my $mail=MIME::Lite->new(
                        Encoding=> '8bit',
                        Type    => 'text/plain; charset=UTF-8',
                        From    => $from,
                        To      => $to,
                        Subject => $_[0],
                        Data    => $text
                );
                $mail->send;
                unlink $_[1];
        }
        move $_[2],$_[3];
}

switch($ARGV[0]){
        case "parse"{
                &parseReview($ru_url,$ru_tmp,$ru_current);
                &parseReview($en_url,$en_tmp,$en_current);
        }
        case "send"{
                &sendMail($ru_subject,$ru_mail,$ru_current,$ru_previous);
                &sendMail($en_subject,$en_mail,$en_current,$en_previous);
        }
        else{
                print "USAGE: ./gsp.pl [option]\nOPTIONS:\n     parse - get reviews\n   send - send reviews via email (need smtp relay)\n";
        }
}