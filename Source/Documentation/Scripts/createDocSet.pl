#!/usr/bin/perl -w

use strict;
use DBI;
require DBD::SQLite;
#use Data::Dumper;
use HTML::Entities;
$| = 1;

my ($program_name, $script_name) = ($0, (defined($ENV{"SCRIPT_NAME"}) && defined($ENV{"SCRIPT_LINENO"})) ? "$ENV{'SCRIPT_NAME'}:$ENV{'SCRIPT_LINENO'}" : "");
#$program_name =~ s/(.*?)\/?([^\/]+)$/$2/;
$program_name =~ s/^$ENV{'PROJECT_DIR'}\/?//;

for my $env (qw(DOCUMENTATION_SQL_DATABASE_FILE DOCUMENTAION_DOCSET_ID DOCUMENTATION_DOCSET_SOURCE_HTML DOCUMENTATION_DOCSET_TEMP_DIR)) {
  if(!defined($ENV{$env}))  { print("${$program_name} error: Environment variable $env not set.\n"); exit(1); }
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$ENV{'DOCUMENTATION_SQL_DATABASE_FILE'}","","", { AutoCommit => 1, RaiseError => 1 });

$dbh->do("PRAGMA synchronous = OFF");
$dbh->do("ANALYZE");

$dbh->begin_work;

my $sqlSelectDSID = $dbh->prepare("SELECT dsid FROM docset WHERE docset = ?");
my $sqlInsertDocset = $dbh->prepare("INSERT INTO docset (docset) VALUES (?)");

$dbh->func( 'docsetid', 1,
sub {
  my ($docset) = (@_);
  my ($row) = ($dbh->selectrow_hashref($sqlSelectDSID, {MaxRows => 1}, ($docset)));
  if ($row) { return($row->{'dsid'}); }
  $sqlInsertDocset->execute($docset);
  $row = $dbh->selectrow_hashref($sqlSelectDSID, {MaxRows => 1}, ($docset));
  if ($row) { return($row->{'dsid'}); } else { return(undef); }
}, 'create_function' 
);

my $sqlSelectFID = $dbh->prepare("SELECT fid FROM files WHERE dsid = docsetid(?) AND path = ? AND file = ?");
my $sqlInsertFiles = $dbh->prepare("INSERT INTO files (dsid, path, file, filePath) VALUES (docsetid(?), ?, ?, ?)");
my $sqlAnalyze = $dbh->prepare("ANALYZE");

$dbh->func( 'filefid', 3,
sub {
  my ($docset, $path, $file) = (@_);
  my ($row) = $dbh->selectrow_hashref($sqlSelectFID, {MaxRows => 1}, ($docset, $path, $file));
  if ($row) { return($row->{'fid'}); }
  $sqlInsertFiles->execute($docset, $path, $file, (($path eq '') ? '' : "$path/") . $file);
  my $fid = $dbh->last_insert_id(undef, undef, undef, undef);
  if(($fid % 59) == 0) { $sqlAnalyze->execute; }
  return($fid);
}, 'create_function' 
);

my $sqlInsertNodeName = $dbh->prepare("INSERT INTO nodeNames (fid, anchor, name, href) VALUES (filefid(?, ?, ?), ?, ?, ?)");
my $sqlSelectRefIDInternal = $dbh->prepare("SELECT refid FROM nodeNames WHERE fid = filefid(?, ?, ?) AND anchor = ?");

$dbh->func( 'refid', 3,
sub {
  my ($docset, $href, $name) = (@_);
  $href =~ /^([^#]*)(?:#?)(.*)$/;
  my($hrefFile, $hrefAnchor) = ($1, $2);
  $hrefFile =~ /(.*?)\/?([^\/]+)$/;
  my ($path, $file, $filePath) = ($1, $2, (($1 eq '') ? $2 : "$1/$2"));
  
  my ($row) = $dbh->selectrow_hashref($sqlSelectRefIDInternal, {MaxRows => 1}, ($docset, $path, $file, $hrefAnchor));
  if ($row) { return($row->{'refid'}); }
  $sqlInsertNodeName->execute($docset, $path, $file, $hrefAnchor, $name, $href);
  my $refid = $dbh->last_insert_id(undef, undef, undef, undef);
  return($refid);
}, 'create_function' 
);

my $sqlSelectRefID = $dbh->prepare("SELECT refid(?, ?, ?) AS refid");

my %xrefs;
for my $row (selectall_hash($dbh, "SELECT DISTINCT linkId, href, apple_ref, file FROM t_xtoc WHERE xref IS NOT NULL AND linkId IS NOT NULL AND href IS NOT NULL")) {
  $xrefs{'name'}->{$row->{'linkId'}} = $row->{'apple_ref'};
  $xrefs{'href'}->{$row->{'href'}} = $row->{'file'} . '#' . $row->{'apple_ref'};
  $xrefs{'file'}->{$row->{'file'}} = $row->{'file'};
}


my $docset = $ENV{'DOCUMENTAION_DOCSET_ID'};

my @htmlFiles = @{$dbh->selectcol_arrayref("SELECT DISTINCT file FROM html ORDER BY file")};
push(@htmlFiles, qw(content.html content_frame.html toc_opened.html));

print("${program_name}:88: note: Rewriting anchors to //apple-ref/ format.\n");
for my $file (@htmlFiles) { processFile($ENV{'DOCUMENTATION_DOCSET_SOURCE_HTML'}, $file, $ENV{'DOCUMENTATION_DOCSET_TEMP_DOCS_DIR'}); }

my @referenceNodes;

for my $row (selectall_hash($dbh, "SELECT DISTINCT ocm.hid AS hid, occl.class AS class, occat.category AS category, toc.tocName AS tocName FROM toc JOIN objCMethods AS ocm ON ocm.tocid = toc.tocid AND ocm.hdcid IS NOT NULL JOIN objCClassCategory AS occat ON occat.occlid = ocm.occlid AND ocm.startsAt >= occat.startsAt AND (occat.startsAt + occat.length) >= (ocm.startsAt) join objCClass AS occl ON ocm.occlid = occl.occlid;")) {
  $sqlInsertNodeName->execute($docset, '', $row->{'tocName'} . '.html', undef, $row->{'tocName'} . ' RegexKit Additions Reference', $row->{'tocName'} . '.html');
  push(@referenceNodes, $row->{'tocName'} . '.html');
}

$sqlInsertNodeName->execute($docset, '', 'Constants.html', undef, 'RegexKit Constants Reference',  'Constants.html'); push(@referenceNodes, 'Constants.html');
$sqlInsertNodeName->execute($docset, '', 'DataTypes.html', undef, 'RegexKit Data Types Reference', 'DataTypes.html'); push(@referenceNodes, 'DataTypes.html');
$sqlInsertNodeName->execute($docset, '', 'Functions.html', undef, 'RegexKit Functions Reference',  'Functions.html'); push(@referenceNodes, 'Functions.html');

for my $row (selectall_hash($dbh, "SELECT ocdef.hid AS hid, occl.class AS class, vt2.text AS filename FROM objCClassDefinition AS ocdef JOIN objcclass AS occl ON ocdef.occlid = occl.occlid JOIN v_tagid AS vt1 ON vt1.hid = ocdef.hid AND vt1.keyword = 'class' AND vt1.text = occl.class JOIN v_tagid AS vt2 ON vt2.hdcid = vt1.hdcid AND vt2.keyword = 'toc' and vt2.arg = 0")) {
  $sqlInsertNodeName->execute($docset, '', $row->{'class'} . '.html', undef, $row->{'class'} . ' Class Reference', $row->{'class'} . '.html');
  push(@referenceNodes, $row->{'class'} . '.html');
}


$sqlInsertNodeName->execute($docset, 'pcre', 'index.html', undef, 'PCRE', 'pcre/index.html');
$sqlInsertNodeName->execute($docset, 'pcre', 'pcresyntax.html', undef, 'PCRE Regex Quick Reference', 'pcre/pcresyntax.html');
$sqlInsertNodeName->execute($docset, 'pcre', 'pcrepattern.html', undef, 'PCRE Regular Expression Syntax', 'pcre/pcrepattern.html');


my (%nodeRefHash, %libraryHash);
for my $row (selectall_hash($dbh, "SELECT refid, href FROM nodeNames ORDER BY refid")) { $nodeRefHash{$row->{'href'}} = $row->{'refid'}; }

$libraryHash{'content.html'} = $nodeRefHash{'content.html'};
$libraryHash{'RegexKitImplementationTopics.html'} = $nodeRefHash{'RegexKitImplementationTopics.html'};
$libraryHash{'RegexKitProgrammingGuide.html'} = $nodeRefHash{'RegexKitProgrammingGuide.html'};
$libraryHash{'pcre/index.html'} = $nodeRefHash{'pcre/index.html'};
$libraryHash{'pcre/pcresyntax.html'} = $nodeRefHash{'pcre/pcresyntax.html'};
$libraryHash{'pcre/pcrepattern.html'} = $nodeRefHash{'pcre/pcrepattern.html'};

my $FH;

open($FH, ">", "$ENV{'DOCUMENTATION_DOCSET_TEMP_DIR'}/$ENV{'DOCUMENTAION_DOCSET_ID'}/Contents/Info.plist");

print $FH <<END_PLIST;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleGetInfoString</key>
    <string>$ENV{'PROJECT_CURRENT_VERSION'}, Copyright 2007 John Engelhart</string>
    <key>CFBundleIdentifier</key>
    <string>$docset</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Reference Library</string>
    <key>CFBundleShortVersionString</key>
    <string>$ENV{'PROJECT_CURRENT_VERSION'}</string>
    <key>CFBundleVersion</key>
    <string>$ENV{'PROJECT_CURRENT_VERSION'}</string>
    <key>DocSetFeedName</key>
    <string>RegexKit</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2007, John Engelhart</string>
</dict>
</plist>
END_PLIST
close($FH); undef($FH);

print("${program_name}:144: note: Creating Tokens.xml file.\n");

my %no_link;
for my $row (selectall_hash($dbh, "SELECT DISTINCT xref FROM xrefs WHERE href IS NULL")) { $no_link{$row->{'xref'}} = 1; }

my %global_xtoc_cache = gen_xtoc_cache();

open($FH, ">", "$ENV{'DOCUMENTATION_DOCSET_TEMP_DIR'}/$ENV{'DOCUMENTAION_DOCSET_ID'}/Contents/Resources/Tokens.xml");

print($FH "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
print($FH "<Tokens version=\"1.0\">\n");

for my $row (@{$global_xtoc_cache{'preprocessorDefines'}}) {
  if(!defined($row)) { next; }
  my ($hdcid, $tags, $tokenAbstract) = ($row->{'hdcid'}, $global_xtoc_cache{'tags'}[$row->{'hdcid'}], "");
  if (defined($tags->{'abstract'})) { $tokenAbstract = "<Abstract type=\"html\">" . simpleHTML($tags->{'abstract'}) . "</Abstract>"; }
  my $refid = $nodeRefHash{$global_xtoc_cache{'xref'}{$row->{'defineName'}}{'file'}};
  $libraryHash{$global_xtoc_cache{'xref'}{$row->{'defineName'}}{'file'}} = $refid;

  print $FH <<END_TOKEN;
  <Token>
    <TokenIdentifier>$global_xtoc_cache{'xref'}{$row->{'defineName'}}{'apple_ref'}</TokenIdentifier>
    <Declaration type="html">&lt;pre&gt;$row->{'cppText'}&lt;/pre&gt;</Declaration>
    $tokenAbstract
    <DeclaredIn>
      <HeaderPath>RegexKit.framework/Headers/$global_xtoc_cache{'headers'}[$row->{'hid'}]{'fileName'}</HeaderPath>
      <FrameworkName>RegexKit</FrameworkName>
    </DeclaredIn>
    <NodeRef refid="$refid" />
    <Path>$global_xtoc_cache{'xref'}{$row->{'defineName'}}{'file'}</Path>
    <Anchor>$global_xtoc_cache{'xref'}{$row->{'defineName'}}{'apple_ref'}</Anchor>
END_TOKEN
  print($FH seealso_tokens("    ", $hdcid));
  print($FH "  </Token>\n");
}

for my $row (@{$global_xtoc_cache{'constantDefines'}}) {
  if(!defined($row)) { next; }
  my ($hdcid, $tags, $tokenAbstract) = ($row->{'hdcid'}, $global_xtoc_cache{'tags'}[$row->{'hdcid'}], "");
  if (defined($tags->{'abstract'})) { $tokenAbstract = "<Abstract type=\"html\">" . simpleHTML($tags->{'abstract'}) . "</Abstract>"; }
  my $refid = $nodeRefHash{$global_xtoc_cache{'xref'}{$row->{'defineName'}}{'file'}};
  $libraryHash{$global_xtoc_cache{'xref'}{$row->{'defineName'}}{'file'}} = $refid;
  
  print $FH <<END_TOKEN;
  <Token>
    <TokenIdentifier>$global_xtoc_cache{'xref'}{$row->{'defineName'}}{'apple_ref'}</TokenIdentifier>
    <Declaration type="html">&lt;pre&gt;$row->{'cppText'}&lt;/pre&gt;</Declaration>
    $tokenAbstract
    <DeclaredIn>
      <HeaderPath>RegexKit.framework/Headers/$global_xtoc_cache{'headers'}[$row->{'hid'}]{'fileName'}</HeaderPath>
      <FrameworkName>RegexKit</FrameworkName>
    </DeclaredIn>
    <NodeRef refid="$refid" />
    <Path>$global_xtoc_cache{'xref'}{$row->{'defineName'}}{'file'}</Path>
    <Anchor>$global_xtoc_cache{'xref'}{$row->{'defineName'}}{'apple_ref'}</Anchor>
END_TOKEN
  print($FH seealso_tokens("    ", $hdcid));
  print($FH "  </Token>\n");
}

for my $row (@{$global_xtoc_cache{'constants'}}) {
  if(!defined($row)) { next; }
  my ($hdcid, $tags, $tokenAbstract) = ($row->{'hdcid'}, $global_xtoc_cache{'tags'}[$row->{'hdcid'}], "");
  if (defined($tags->{'abstract'})) { $tokenAbstract = "<Abstract type=\"html\">" . simpleHTML($tags->{'abstract'}) . "</Abstract>"; }
  my $refid = $nodeRefHash{$global_xtoc_cache{'xref'}{$row->{'name'}}{'file'}};
  $libraryHash{$global_xtoc_cache{'xref'}{$row->{'name'}}{'file'}} = $refid;

  print $FH <<END_TOKEN;
  <Token>
    <TokenIdentifier>$global_xtoc_cache{'xref'}{$row->{'name'}}{'apple_ref'}</TokenIdentifier>
    <Declaration type="html">&lt;pre&gt;$row->{'fullText'}&lt;/pre&gt;</Declaration>
    $tokenAbstract
    <DeclaredIn>
      <HeaderPath>RegexKit.framework/Headers/$global_xtoc_cache{'headers'}[$row->{'hid'}]{'fileName'}</HeaderPath>
      <FrameworkName>RegexKit</FrameworkName>
    </DeclaredIn>
    <Availability distribution="RegexKit">
      <IntroducedInVersion bitsize="32">0.2.0</IntroducedInVersion>
      <IntroducedInVersion bitsize="64">0.3.0</IntroducedInVersion>
    </Availability>
    <NodeRef refid="$refid" />
    <Path>$global_xtoc_cache{'xref'}{$row->{'name'}}{'file'}</Path>
    <Anchor>$global_xtoc_cache{'xref'}{$row->{'name'}}{'apple_ref'}</Anchor>
END_TOKEN
  print($FH seealso_tokens("    ", $hdcid));
  print($FH "  </Token>\n");
}


for my $row (selectall_hash($dbh, "SELECT DISTINCT ocm.hid AS hid, occl.class AS class, occat.category AS category, toc.tocName AS tocName FROM toc JOIN objCMethods AS ocm ON ocm.tocid = toc.tocid AND ocm.hdcid IS NOT NULL JOIN objCClassCategory AS occat ON occat.occlid = ocm.occlid AND ocm.startsAt >= occat.startsAt AND (occat.startsAt + occat.length) >= (ocm.startsAt) join objCClass AS occl ON ocm.occlid = occl.occlid;")) {
  my $refid = $nodeRefHash{$row->{'tocName'} . '.html'};
  $libraryHash{$row->{'tocName'} . '.html'} = $refid;
  print $FH <<END_TOKEN;
  <Token>
    <TokenIdentifier>//apple_ref/occ/cat/$row->{'class'}($row->{'category'})</TokenIdentifier>
    <DeclaredIn>
      <HeaderPath>RegexKit.framework/Headers/$global_xtoc_cache{'headers'}[$row->{'hid'}]{'fileName'}</HeaderPath>
      <FrameworkName>RegexKit</FrameworkName>
    </DeclaredIn>
  <Availability distribution="RegexKit">
  <IntroducedInVersion bitsize="32">0.2.0</IntroducedInVersion>
  <IntroducedInVersion bitsize="64">0.3.0</IntroducedInVersion>
  </Availability>
  <NodeRef refid="$refid" />
    <Path>$row->{'tocName'}.html</Path>
  </Token>
END_TOKEN
}


for my $row (selectall_hash($dbh, "SELECT ocdef.hid AS hid, occl.class AS class, vt2.text AS filename FROM objCClassDefinition AS ocdef JOIN objcclass AS occl ON ocdef.occlid = occl.occlid JOIN v_tagid AS vt1 ON vt1.hid = ocdef.hid AND vt1.keyword = 'class' AND vt1.text = occl.class JOIN v_tagid AS vt2 ON vt2.hdcid = vt1.hdcid AND vt2.keyword = 'toc' and vt2.arg = 0")) {
  my $refid = $nodeRefHash{$row->{'class'} . '.html'};
  $libraryHash{$row->{'class'} . '.html'} = $refid;
  print $FH <<END_TOKEN;
  <Token>
    <TokenIdentifier>//apple_ref/occ/cl/$row->{'class'}</TokenIdentifier>
    <DeclaredIn>
      <HeaderPath>RegexKit.framework/Headers/$global_xtoc_cache{'headers'}[$row->{'hid'}]{'fileName'}</HeaderPath>
      <FrameworkName>RegexKit</FrameworkName>
    </DeclaredIn>
  <Availability distribution="RegexKit">
  <IntroducedInVersion bitsize="32">0.2.0</IntroducedInVersion>
  <IntroducedInVersion bitsize="64">0.3.0</IntroducedInVersion>
  </Availability>
  <NodeRef refid="$refid" />
    <Path>$row->{'filename'}.html</Path>
  </Token>
END_TOKEN
}


for my $tocName (keys %{$global_xtoc_cache{'toc'}{'contentsForToc'}}) {
  #print($FH "  <File path=\"${tocName}.html\">\n");
  for my $tx (0 .. $#{$global_xtoc_cache{'toc'}{'contentsForToc'}{$tocName}}) {
    my $at = $global_xtoc_cache{'toc'}{'contentsForToc'}{$tocName}[$tx];
    if($at->{'table'} eq "objCMethods") { print($FH meth_token("    ", $at->{'id'})); }
    elsif($at->{'table'} eq "prototypes") { print($FH func_token("    ",$at->{'id'})); }
    elsif($at->{'table'} eq "typedefEnum") { print($FH typedef_token("    ",$at->{'id'})); }
  }
  #print($FH "  </File>\n\n\n");
}


print($FH "</Tokens>\n");
close($FH); undef($FH);

printf("Tokens.xml file size: %.1fK.\n", ((stat("$ENV{'DOCUMENTATION_DOCSET_TEMP_DIR'}/$ENV{'DOCUMENTAION_DOCSET_ID'}/Contents/Resources/Tokens.xml"))[7]) / 1024.0);

print("${program_name}:278: note: Creating Nodes.xml file.\n");

my $docSetNodes = <<END_NODES;
<?xml version="1.0" encoding="UTF-8"?>
<DocSetNodes version="1.0">
  <TOC>
    <Node>
      <Name>Root</Name>
      <Path>content.html</Path>
      <Subnodes>
        <Node>
          <Name>RegexKit</Name>
          <Path>content.html</Path>
          <Subnodes>
            <Node>
              <Name>Reference</Name>
              <Path>content.html</Path>
              <Subnodes>
END_NODES
for my $file (sort @referenceNodes) {
  $docSetNodes .= "                <NodeRef refid=\"$nodeRefHash{$file}\" />\n";
  $libraryHash{$file} = $nodeRefHash{$file};
}
$docSetNodes .= <<END_NODES;
              </Subnodes>
            </Node>
            <Node>
              <Name>Guides</Name>
              <Path>content.html</Path>
              <Subnodes>
                <NodeRef refid="$nodeRefHash{'RegexKitImplementationTopics.html'}" />
                <NodeRef refid="$nodeRefHash{'RegexKitProgrammingGuide.html'}" />
              </Subnodes>
            </Node>
          </Subnodes>
        </Node>
      </Subnodes>
    </Node>
  </TOC>
  <Library>
END_NODES
for my $href (sort keys %libraryHash) {
  my $refid = $libraryHash{$href};
  if(!defined($refid)) { $docSetNodes .= "    <!-- href '$href' is undefined. -->\n"; next; }
  my ($row) = $dbh->selectrow_hashref("SELECT f.filePath AS filePath, nn.name AS name, nn.anchor AS anchor FROM nodeNames AS nn JOIN files AS f ON f.fid = nn.fid WHERE nn.refid = $refid", {MaxRows => 1});
  my $anchor = (defined($row->{'anchor'})) ? ('<Anchor>' . $row->{'anchor'} . '</Anchor> ') : ""; 
  $docSetNodes .= "    <Node id=\"$refid\"> <Name>$row->{'name'}</Name> <Path>$row->{'filePath'}</Path> ${anchor}</Node>\n"
}

$docSetNodes .= "  </Library>\n";
$docSetNodes .= "</DocSetNodes>\n";


open($FH, ">", "$ENV{'DOCUMENTATION_DOCSET_TEMP_DIR'}/$ENV{'DOCUMENTAION_DOCSET_ID'}/Contents/Resources/Nodes.xml"); print($FH $docSetNodes); close($FH); undef($FH);


$dbh->commit;

undef $sqlSelectRefID;
undef $sqlSelectRefIDInternal;
undef $sqlSelectDSID;
undef $sqlInsertDocset;
undef $sqlSelectFID;
undef $sqlInsertFiles;
undef $sqlInsertNodeName;
undef $sqlAnalyze;

$dbh->disconnect();
exit(0);

sub processFile {
  my($inpath, $file, $outpath, $in, $out, $size, $lastm, $FILE_HANDLE) = ($_[0], $_[1], $_[2], "", "", (stat("$_[0]/$_[1]"))[7], 0);
  print("Rewriting: $file\n");
  if(! -r "$inpath/$file")  { print(STDERR "IN  Not readable: $file\n"); exit(1); return(undef); }
  if(! -w "$outpath/$file") { print(STDERR "OUT Not writeable: $file\n"); exit(1); return(undef); }

  open($FILE_HANDLE, "<", "$inpath/$file"); sysread($FILE_HANDLE, $in, $size); close($FILE_HANDLE); undef($FILE_HANDLE);

  study($in);
  while($in =~ /((<a\s+[^>]*)(name|href)="([^"]*)"([^>]*>))/sgi) {
    if(defined($xrefs{lc($3)}{$4})) { $out .= substr($in, $lastm, $-[0] - $lastm) . $2 . $3 . "=\"". $xrefs{lc($3)}{$4} . "\"" . $5; $lastm = $+[0]; }
  }
  $out .= substr($in, $lastm, $size - $lastm);
  undef($in);

  open($FILE_HANDLE, ">", "$outpath/$file"); print($FILE_HANDLE $out); close($FILE_HANDLE); undef($FILE_HANDLE);

  if($file eq "toc.html") { processToc($out); }
  return($out);
}


sub processToc {
  my($in) = @_;

  study($in);
  while($in =~ /(<a\s+[^>]*href="([^"]*)"[^>]*>([^<]*)<\/a>)/sgi) {
    my($match, $href, $body) = ($1, $2, $3);
    $href =~ /^([^#]*)(?:#?)(.*)$/;
    my($file, $anchor) = ($1, $2);
#    if(defined($xrefs{'file'}{$file})) { next; }
    $file =~ /(.*?)\/?([^\/]+)$/;
    my ($nodePath, $nodeFile, $filePath) = ($1, $2, (($1 eq '') ? $2 : "$1/$2"));
    $sqlInsertNodeName->execute($docset, $nodePath, $nodeFile, $anchor eq "" ? undef : $anchor, $body, "$filePath" . (($anchor eq "") ? '' : "#$anchor"));
  }
}


sub extractLinks {
  my($text) = @_;
  my %links;
  while ($text =~ /\@link\s(.*?)\s(.*?)\s?\@\/link/sg) { my ($x, $y) = ($1, $1); $y =~ s?//apple_ref/\w+/\w+/(\w+)(\?:/.*)\??$1?; $links{$x} = $y; }
  return(%links);
}

sub replaceLinks {
  my($text) = ($_[0], $_[1]);
  my(%links) = extractLinks($text);

  for my $atLink (sort keys %links) {
    if ($no_link{$links{$atLink}}) {
      $text =~ s/\@link\s+$atLink\s+(.*?)\s?\@\/link/{
        my $x=$1;
        if($x !~ ?(\?i)<span class=\"code\">(.*\?)<\/span>?) { $x="<code>$x<\/code>"; }
        $x
      }/sge;
    } else {
      if (defined($global_xtoc_cache{'xref'}->{$links{$atLink}}{'href'})) {
        $text =~ s/\@link\s+$atLink\s+(.*?)\s?\@\/link/{
          my $x = $1;
          my $linkClass = defined($global_xtoc_cache{'xref'}->{$links{$atLink}}{'class'}) ? $global_xtoc_cache{'xref'}->{$links{$atLink}}{'class'} : "";
          my $classText = $linkClass ne "" ? " class=\"$linkClass\"" : "";
          $x =~ s?<span class=\"$linkClass\">(.*\?)<\/span>?$1?sg;
          $x = "<a href=\"$global_xtoc_cache{'xref'}->{$links{$atLink}}{'apple_href'}\">$x<\/a>"
        }/sge;
      } else {
        $text =~ s/\@link\s+$atLink\s+(.*?)\s?\@\/link/$1/sg;
      }
    }
  }
  return($text);
}


sub func_token {
  my $sp = shift(@_);
  my $pid = shift(@_);
  my($token, $row) = ("");
  
  if(defined($global_xtoc_cache{'functions'}[$pid])) {
    my $row = $global_xtoc_cache{'functions'}[$pid]; 
    my ($pretty, $hdcid, $tags) = ($row->{'prettyText'}, $row->{'hdcid'}, $global_xtoc_cache{'tags'}[$row->{'hdcid'}]);
    $pretty =~ s/(\((.*?)\))/{my ($full, $mid) = ($1, $2); $mid =~ s?(\S+)?if(defined($global_xtoc_cache{'xref'}{$1}{'apple_href'})) { "&lt;a href=\"$global_xtoc_cache{'xref'}{$1}{'apple_href'}\"&gt;$1&lt;\/a&gt;" } else { $1 }?sge; "($mid)"} /sge;
    my $refid = $nodeRefHash{$global_xtoc_cache{'xref'}{$tags->{'function'}}{'file'}};
    $libraryHash{$global_xtoc_cache{'xref'}{$tags->{'function'}}{'file'}} = $refid;

    $token .= $sp . "<Token>\n";
    $token .= $sp . "  <TokenIdentifier>" . $global_xtoc_cache{'xref'}{$tags->{'function'}}{'apple_ref'} . "</TokenIdentifier>\n";
    if (defined($tags->{'abstract'})) { $token .= $sp . "  <Abstract type=\"html\">" . simpleHTML($tags->{'abstract'}) . "</Abstract>\n"; }
    $token .= $sp . "  <Declaration type=\"html\">&lt;pre&gt;$pretty&lt;/pre&gt;</Declaration>\n";
    $token .= $sp . "  <DeclaredIn>\n";
    $token .= $sp . "    <HeaderPath>/Developer/Leopard/RegexKit/RegexKit.framework/Headers/$global_xtoc_cache{'headers'}[$row->{'hid'}]{'fileName'}</HeaderPath>\n";
    $token .= $sp . "    <FrameworkName>RegexKit</FrameworkName>\n";
    $token .= $sp . "  </DeclaredIn>\n";
    $token .= $sp . "  <Availability distribution=\"RegexKit\">\n";
    $token .= $sp . "    <IntroducedInVersion bitsize=\"32\">0.2.0</IntroducedInVersion>\n";
    $token .= $sp . "    <IntroducedInVersion bitsize=\"64\">0.3.0</IntroducedInVersion>\n";
    $token .= $sp . "  </Availability>\n";
    $token .= $sp . "  <NodeRef refid=\"$refid\" />\n";
    $token .= seealso_tokens($sp . "  ", $hdcid);
    $token .= $sp . "  <Anchor>" . $global_xtoc_cache{'xref'}{$tags->{'function'}}{'apple_ref'} . "</Anchor>\n";
    $token .= $sp . "</Token>\n";
  }
  
  return($token);
}

sub meth_token {
  my $sp = shift(@_);
  my $ocmid = shift(@_);
  my($token, $row) = ("");
  
  if(defined($global_xtoc_cache{'methods'}[$ocmid])) {
    my $row = $global_xtoc_cache{'methods'}[$ocmid]; 
    my ($pretty, $hdcid, $tags, $mxref) = ($row->{'prettyText'}, $row->{'hdcid'}, $global_xtoc_cache{'tags'}[$row->{'hdcid'}], "$row->{'class'}/$row->{'type'}$row->{'selector'}");
    my $type = $row->{'type'} eq "-" ? "instm" : "clm";
    $pretty =~ s/(\((.*?)\))/{my ($full, $mid) = ($1, $2); $mid =~ s?(\S+)?if(defined($global_xtoc_cache{'xref'}{$1}{'apple_href'})) { "&lt;a href=\"$global_xtoc_cache{'xref'}{$1}{'apple_href'}\"&gt;$1&lt;\/a&gt;" } else { $1 }?sge; "($mid)"} /sge;
    my $refid = $nodeRefHash{$global_xtoc_cache{'xref'}{$mxref}{'file'}};
    $libraryHash{$global_xtoc_cache{'xref'}{$mxref}{'file'}} = $refid;

    $token .= $sp . "<Token>\n";
    $token .= $sp . "  <TokenIdentifier>$global_xtoc_cache{'xref'}{$mxref}{'apple_ref'}</TokenIdentifier>\n";
    if (defined($tags->{'abstract'})) { $token .= $sp . "  <Abstract type=\"html\">" . simpleHTML($tags->{'abstract'}) . "</Abstract>\n"; }
    $token .= $sp . "  <Declaration type=\"html\">&lt;pre&gt;$pretty&lt;/pre&gt;</Declaration>\n";
    $token .= $sp . "  <DeclaredIn>\n";
    $token .= $sp . "    <HeaderPath>/Developer/Leopard/RegexKit/RegexKit.framework/Headers/$global_xtoc_cache{'headers'}[$row->{'hid'}]{'fileName'}</HeaderPath>\n";
    $token .= $sp . "    <FrameworkName>RegexKit</FrameworkName>\n";
    $token .= $sp . "  </DeclaredIn>\n";
    $token .= $sp . "  <Availability distribution=\"RegexKit\">\n";
    $token .= $sp . "    <IntroducedInVersion bitsize=\"32\">0.2.0</IntroducedInVersion>\n";
    $token .= $sp . "    <IntroducedInVersion bitsize=\"64\">0.3.0</IntroducedInVersion>\n";
    $token .= $sp . "  </Availability>\n";
    $token .= $sp . "  <NodeRef refid=\"$refid\" />\n";
    $token .= $sp . "  <Anchor>" . $global_xtoc_cache{'xref'}{$mxref}{'apple_ref'} . "</Anchor>\n";
    $token .= seealso_tokens($sp . "  ", $hdcid);
    $token .= $sp . "</Token>\n";
  }
  
  return($token);
}


sub seealso_tokens {
  my $sp = shift(@_);
  my $hdcid = shift(@_);
  my $tags = $global_xtoc_cache{'tags'}[$hdcid];

  my $token = "";
  if (defined($tags->{'seealso'})) {
    my(@related_tokens, @related_documents, @related_sourcecode);
    for my $s (@{$tags->{'seealso'}}) {
      my(%links) = extractLinks($s);

      for my $atLink (sort keys %links) {
        if (defined($global_xtoc_cache{'xref'}->{$links{$atLink}}{'apple_ref'})) {
          push(@related_tokens, $sp . "  <TokenIdentifier>".$global_xtoc_cache{'xref'}->{$links{$atLink}}{'apple_ref'} . "</TokenIdentifier>");
        }
      }
      if($s =~ /<a\s+[^>]*href="([^\"]*)"[^>]*>(.*)<\/a>/si) {
        my ($href, $name) = ($1, $2);
        if($href !~ /^http:/) {
          my ($row) = $dbh->selectrow_hashref($sqlSelectRefID, {MaxRows => 1}, ($docset, $href, $name));
          if ($row) { $nodeRefHash{$href} = $row->{'refid'}; }
          if (defined($nodeRefHash{$href})) {
            push(@related_documents, $sp . '  <NodeRef refid="' . $nodeRefHash{$href} . '" />');
            $libraryHash{$href} = $nodeRefHash{$href};
          }
        }
      }
    }
    if($#related_tokens > -1)    { $token .= $sp . "<RelatedTokens>\n"    . join("\n", @related_tokens)    . "\n" . $sp ."</RelatedTokens>\n";    }
    if($#related_documents > -1) { $token .= $sp . "<RelatedDocuments>\n" . join("\n", @related_documents) . "\n" . $sp ."</RelatedDocuments>\n"; }
  }
  return($token);
}

sub typedef_token {
  my $sp = shift(@_);
  my $tdeid = shift(@_);

  if(defined($global_xtoc_cache{'typedefs'}[$tdeid])) {
    my $row = $global_xtoc_cache{'typedefs'}[$tdeid]; 
    my ($token, $tags, $hdcid, $const_token) = ("", $global_xtoc_cache{'tags'}[$row->{'hdcid'}], $row->{'hdcid'}, "");
    my $refid = $nodeRefHash{$global_xtoc_cache{'xref'}{$row->{'name'}}{'file'}};
    $libraryHash{$global_xtoc_cache{'xref'}{$row->{'name'}}{'file'}} = $refid;

    $token .= $sp . "<Token>\n";
    $token .= $sp . "  <TokenIdentifier>" . $global_xtoc_cache{'xref'}{$row->{'name'}}{'apple_ref'} . "</TokenIdentifier>\n";
    if (defined($tags->{'abstract'})) { $token .= $sp . "  <Abstract type=\"html\">" . simpleHTML($tags->{'abstract'}) . "</Abstract>\n"; }
    $token .= $sp . "  <Declaration type=\"html\">&lt;pre&gt;$row->{'name'}&lt;/pre&gt;</Declaration>\n";
    $token .= $sp . "  <DeclaredIn>\n";
    $token .= $sp . "    <HeaderPath>/Developer/Leopard/RegexKit/RegexKit.framework/Headers/$global_xtoc_cache{'headers'}[$row->{'hid'}]{'fileName'}</HeaderPath>\n";
    $token .= $sp . "    <FrameworkName>RegexKit</FrameworkName>\n";
    $token .= $sp . "  </DeclaredIn>\n";
    $token .= $sp . "  <Availability distribution=\"RegexKit\">\n";
    $token .= $sp . "    <IntroducedInVersion bitsize=\"32\">0.2.0</IntroducedInVersion>\n";
    $token .= $sp . "    <IntroducedInVersion bitsize=\"64\">0.3.0</IntroducedInVersion>\n";
    $token .= $sp . "  </Availability>\n";
    $token .= $sp . "  <NodeRef refid=\"$refid\" />\n";
    $token .= seealso_tokens($sp . "  ", $hdcid);
    $token .= $sp . "  <Anchor>" . $global_xtoc_cache{'xref'}{$row->{'name'}}{'apple_ref'} . "</Anchor>\n";
    $token .= $sp . "</Token>\n";
    
    for my $tderow (@{$global_xtoc_cache{'enums'}[$row->{'tdeid'}]}) {
      $token .= $sp . "<Token>\n";
      $token .= $sp . "  <TokenIdentifier>" . $global_xtoc_cache{'xref'}{$tderow->{'identifier'}}{'apple_ref'} . "</TokenIdentifier>\n";
      if (defined($tderow->{'tagText'})) { $token .= $sp . "  <Abstract type=\"html\">" . simpleHTML($tderow->{'tagText'}) . "</Abstract>\n"; }
      $token .= $sp . "  <Declaration type=\"html\">&lt;pre&gt;$tderow->{'identifier'}&lt;/pre&gt;</Declaration>\n";
      $token .= $sp . "  <DeclaredIn>\n";
      $token .= $sp . "    <HeaderPath>/Developer/Leopard/RegexKit/RegexKit.framework/Headers/$global_xtoc_cache{'headers'}[$row->{'hid'}]{'fileName'}</HeaderPath>\n";
      $token .= $sp . "    <FrameworkName>RegexKit</FrameworkName>\n";
      $token .= $sp . "  </DeclaredIn>\n";
      $token .= $sp . "  <Availability distribution=\"RegexKit\">\n";
      $token .= $sp . "    <IntroducedInVersion bitsize=\"32\">0.2.0</IntroducedInVersion>\n";
      $token .= $sp . "    <IntroducedInVersion bitsize=\"64\">0.3.0</IntroducedInVersion>\n";
      $token .= $sp . "  </Availability>\n";
      $token .= $sp . "  <NodeRef refid=\"$refid\" />\n";
      $token .= $sp . "  <Anchor>" . $global_xtoc_cache{'xref'}{$tderow->{'identifier'}}{'apple_ref'} . "</Anchor>\n";
      $token .= $sp . "</Token>\n";
    }
    return($token);
  }
}  


sub stripExcess {
  my($strip) = shift(@_);

  $strip = stripBoxes($strip);
  $strip =~ s/\@link .*? (.*?)\s?\@\/link/$1/sg;
  $strip =~ s/<[^>]*>//gs;
  $strip =~ s/\n//gs;
  
  $strip = encode_entities($strip);
  
  return($strip);
}

sub stripBoxes {
  my($strip) = shift(@_);

  $strip =~ s/<div\s+[^>]*\bclass="[^\"]*\bbox\b[^\"]*"[^>]*>.*(?:<\/div>\s*){4}//sg;
  
  return($strip);
}

sub simpleHTML {
  my $html = shift(@_);

  $html = stripBoxes($html);
  $html = replaceLinks($html);
  $html =~ s/<span class="(?:nobr)">(.*?)<\/span>/$1/sig;
  $html =~ s/<span class="[^"]*\b(?:code|regex)\b[^"]*">(.*?)<\/span>/<code>$1<\/code>/sig;
  $html =~ s/<span class="[^"]*\b(?:argument)\b[^"]*">(.*?)<\/span>/<i>$1<\/i>/sig;
  $html = encode_entities($html);

  return($html);
}


sub gen_xtoc_cache {
  my (%cache);
  
  for my $row (selectall_hash($dbh, "SELECT DISTINCT xref, linkId, href, apple_ref, file FROM t_xtoc WHERE xref IS NOT NULL AND linkId IS NOT NULL AND href IS NOT NULL")) {
    $cache{'xref'}->{$row->{'xref'}}{'linkId'} = $row->{'linkId'};
    $cache{'xref'}->{$row->{'xref'}}{'href'} = $row->{'href'};
    $cache{'xref'}->{$row->{'xref'}}{'apple_ref'} = $row->{'apple_ref'};
    $cache{'xref'}->{$row->{'xref'}}{'apple_href'} = $row->{'file'} . '#' . $row->{'apple_ref'};
    $cache{'xref'}->{$row->{'xref'}}{'file'} = $row->{'file'};
    $cache{'xref'}->{$row->{'xref'}}{'class'} = "code";
  }

  for my $row (selectall_hash($dbh, "SELECT DISTINCT xref, class, href  FROM xrefs WHERE href IS NOT NULL")) {
    $cache{'xref'}->{$row->{'xref'}}{'href'} = $row->{'href'};
    $cache{'xref'}->{$row->{'xref'}}{'class'} = $row->{'class'};
   }
  
  for my $row (selectall_hash($dbh, "SELECT DISTINCT tbl, idCol, id, hdtype, tocName, groupName, pos, linkId, apple_ref, href, titleText, linkText, file FROM t_xtoc WHERE tocName IS NOT NULL AND pos IS NOT NULL AND id IS NOT NULL AND href IS NOT NULL AND linkText IS NOT NULL ORDER BY pos, linkText")) {
    if(defined($row->{'groupName'})) { $cache{'toc'}{'tocGroups'}{$row->{'tocName'}}[$row->{'pos'} - 1] = $row->{'groupName'}; }
    if(defined($row->{'file'}))      { $cache{'toc'}{$row->{'tocName'}}{'file'} = $row->{'file'}; }
    my $entry = {'table' => $row->{'tbl'}, 'idColumn' => $row->{'idCol'}, 'id' => $row->{'id'}, 'type' => $row->{'hdtype'}, 'href' => $row->{'href'}, 'linkId' => $row->{'linkId'}, 'apple_ref' => $row->{'apple_ref'}, 'linkText' => $row->{'linkText'}};
    if(defined($row->{'titleText'})) { $entry->{'titleText'} = stripExcess($row->{'titleText'}); }
    push(@{$cache{'toc'}{'groupEntries'}{$row->{'tocName'}}[$row->{'pos'} - 1]}, $entry);
  }
  
  for my $row (selectall_hash($dbh, "SELECT DISTINCT tbl, idCol, id, hdtype, tocName, linkId, apple_ref, href, linkText FROM t_xtoc WHERE tocName IS NOT NULL AND pos IS NOT NULL AND id IS NOT NULL AND href IS NOT NULL AND linkText IS NOT NULL ORDER BY linkText")) {
    push(@{$cache{'toc'}{'contentsForToc'}{$row->{'tocName'}}}, {'table' => $row->{'tbl'}, 'idColumn' => $row->{'idCol'}, 'id' => $row->{'id'}, 'type' => $row->{'hdtype'}, 'href' => $row->{'href'}, 'linkId' => $row->{'linkId'},'apple_ref' => $row->{'apple_ref'}, 'linkText' => $row->{'linkText'}});
  }

  for my $row (selectall_hash($dbh, "SELECT * FROM v_hd_tags ORDER BY hdcid, tpos")) {
    my $p = defined($row->{'arg1'}) ? [$row->{'arg0'}, $row->{'arg1'}] : $row->{'arg0'};
    if($row->{'multiple'} == 0) { $cache{'tags'}[$row->{'hdcid'}]{$row->{'keyword'}} = $p; }
    else { push(@{$cache{'tags'}[$row->{'hdcid'}]{$row->{'keyword'}}}, $p); }
  }

  for my $row (selectall_hash($dbh, "SELECT ocm.*, occ.class AS class FROM objCMethods AS ocm JOIN objCClass AS occ ON ocm.occlid = occ.occlid WHERE ocm.hdcid IS NOT NULL")) { $cache{'methods'}[$row->{'ocmid'}] = $row; }
  for my $row (selectall_hash($dbh, "SELECT * FROM prototypes WHERE hdcid IS NOT NULL")) { $cache{'functions'}[$row->{'pid'}] = $row; }
  for my $row (selectall_hash($dbh, "SELECT * FROM typedefEnum WHERE hdcid IS NOT NULL")) { $cache{'typedefs'}[$row->{'tdeid'}] = $row; }
  for my $row (selectall_hash($dbh, "SELECT e.*, vhd.arg1 AS tagText FROM enumIdentifier AS e JOIN v_hd_tags AS vhd ON vhd.hdcid = e.hdcid AND vhd.keyword = 'constant' AND vhd.arg0 = e.identifier WHERE e.hdcid IS NOT NULL ORDER BY tdeid, position")) { $cache{'enums'}[$row->{'tdeid'}][$row->{'position'}] = $row; }
  for my $row (selectall_hash($dbh, "SELECT * FROM constant WHERE hdcid IS NOT NULL ORDER BY name")) { push(@{$cache{'constants'}}, $row); }  
  for my $row (selectall_hash($dbh, "SELECT * FROM define WHERE hdcid IS NOT NULL ORDER BY defineName")) { push(@{$cache{'defines'}}, $row); }
  for my $row (selectall_hash($dbh, "SELECT * FROM define WHERE hdcid IN (SELECT hdcid FROM t_xtoc WHERE tocName = 'Constants' AND groupName = 'Constants') ORDER BY defineName")) { push(@{$cache{'constantDefines'}}, $row); }
  for my $row (selectall_hash($dbh, "SELECT * FROM define WHERE hdcid IN (SELECT hdcid FROM t_xtoc WHERE tocName = 'Constants' AND groupName = 'Preprocessor Macros') AND cppText IS NOT NULL ORDER BY defineName")) { push(@{$cache{'preprocessorDefines'}}, $row); }
  for my $row (selectall_hash($dbh, "SELECT * FROM headers")) { $cache{'headers'}[$row->{'hid'}] = $row; }
  
  return(%cache);
}


sub selectall_hash {
  my($dbh, $stmt, @args, @results) = (shift(@_), shift(@_), @_);
  my $sth = (ref $stmt) ? $stmt : $dbh->prepare($stmt, undef) or return;
  $sth->execute(@args) or return;
  while (my $row = $sth->fetchrow_hashref) { push(@results, $row); }
  $sth->finish;
  return(@results);
}
