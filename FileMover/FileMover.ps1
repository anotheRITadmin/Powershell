param([string]$path,
       [string]$fe="*.*",
       [int]$nm = 1,
      [int]$nd = 30,
      [bool]$Gzip = $False,
      [bool]$D = $False
      )
        
#$path = "\\prod-dfeed-02\e$\TrackingLogger\Pointers\"
#$path = "C:\scripts\"
$if_older_day_move = $nm 
$if_older_day_del = $nd
$file_ext = $fe
$isGzip = $Gzip
$isDelete = $D
write-host $args[0]
#doing param checks
if ($path -eq "" -or $path -eq "--help" -or $path -eq "-help")
{
    $Help = $True
}
if ($Help -eq $True)
{
    cls
    write-host ""
    write-host "Example: ./FileMover [-path] (-fe|-nm|-nd|-Gzip|-D)"
    write-host "path - Directory Path of where the clean will happen"
    write-host "fe - Wildcard for specific file name and extension"
    write-host "nm - Number of day(s) back for files to move. If 2, anything older than 2 day will be moved. Default: 1 day"
    write-host "nd - Number of days(s) back to delete file. If 2, anything older than 2 days will be delete. Default: 30 days"
    write-host "Gzip - [0,1] Enable file to be gzip that are being moved or already in the archive path 0=false 1=true" 
    write-host "D - [0,1] Enable file for deletion based on -nd  0=false 1=true"
    write-host ""
    break;
}





Function ProcessFile($p)
{
    if((test-path  $p) -eq $False)
    {
        Write-host "Path does not exist" $p
        Break;
    }
    
    $files = get-childitem ($p + $file_ext)|where-object {$_.PSIsContainer -eq $False}
    $count = $files|measure-object
    
    foreach($f in $files)
    {
        if($count.count -eq 0)
        {
            #do nothing
        }
        elseif(($f.lastwritetime -lt (get-date).AddDays(-1 * $if_older_day_del)) -and $isDelete -eq $True)
        {
            #write-host "Removing file " $f.name 
            remove-item $f.fullname -force   
        }
            
        elseif ($f.lastwritetime -lt (get-date).AddDays(-1 * $if_older_day_move))
        {
            $dd = get-date $f.lastwritetime
            $month = get-date $dd -format MM
            $year = get-date $dd -format yyyy
            $day = get-date $dd -format dd
            #write-host  "move" $f.fullname ($f.Directoryname + "\$year\$month\$day\")
            if ((test-path ($f.Directoryname + "\$year\$month\$day\")) -eq $False)
            {
                mkdir ($f.Directoryname + "\$year\$month\$day\")
            }
            
            move $f.fullname ($f.Directoryname + "\$year\$month\$day\")
            
            if($isGzip -eq $True){Gzip-File($f.Directoryname + "\$year\$month\$day\" + $f.name)}
            
        }
        
    }
    
    
    
}

function Gzip-File
{
    param
    (
        [String]$inFile = $(throw “Gzip-File: No filename specified”),
        [String]$outFile = $($inFile + “.gz”)
    );
    trap
    {
        Write-Host “Received an exception: $_. Exiting.”;
        break;
    }

    if (!(Test-Path $inFile))
    {
        “Input file $inFile does not exist.”;
        exit 1;
    }
    
    if(((get-item $infile).extension) -eq ".gz")
    {
        "$outfile exists"
        exit 1;
    }
    
    
    Write-Host “Compressing $inFile to $outFile.” (get-date);
    $input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read);
    $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $output, ([IO.Compression.CompressionMode]::Compress)

    try
    {
        $buffer = New-Object byte[](1024);
        while($true)
        {
            $read = $input.Read($buffer, 0, 1024)
            if ($read -le 0)
            {
                break;
            }
            $gzipStream.Write($buffer, 0, $read)
        }
    }
    finally
    {
        $gzipStream.Close();
        $output.Close();
        $input.Close();
    }
    
    
   
  set-itemproperty $outfile lastwritetime ((get-item $inFile).lastwritetime)
  if ((get-item $outfile).exists -eq "True" -and (get-item $infile).exists -eq "True" )
  {
    del $infile
  }
  
    
}

Function ProcessArchive($p)
{
    #check this and last year
    $year = (get-date).year
    if((test-path ($p+$year)) -eq $True)
    {
        $files = get-childitem ($p+$year) -recurse|where-object {$_.PSIsContainer -eq $False}
        if ($isGzip -eq $True)
        {
            GzipList($files)
        }
        if ($isDelete -eq $True)
        {
            DeleteList($files)
        }
        
      
        
    }
    
    $year = $year - 1
    if((test-path($p+$year)) -eq $True)
    {
    }
 }

Function GzipList($list)
{
    if ($isGzip -eq $True)
    {
        foreach($f in $list)
        {
            Gzip-File($f.fullname)
        }
    }
    
}

Function DeleteList($list)
{
    if ($isDelete -eq $True)
    {
        foreach($f in $list)
        {
            if ($f.lastwritetime -lt (get-date).addDays(-1*$if_older_day_del)){remove-item ($f.fullname) -force}
        }
    }
}

function DeleteEmptyFolder([string]$p,[int]$x)
{
    #Param([string]$p, [int]$x=1)
    
    $year = ((get-date).addYears(-1 * [int]$x)).year
    #write-host "$year $x $p"
    for($i=$year;$i -le ((get-date).year);$i++)
    {
        #write-host "checking path" ($p + $i)
        if((test-path ($p + $i)) -eq -$True)
        {   
            $folders = get-childitem ($p + $i) -recurse|where-object {$_.PSIsContainer -eq $True}
            Foreach($f in $folders)
            { 
                $c = dir $f.fullname -recurse | measure-object -line|select lines
                #write-host $f.fullname $c.lines
                if ($c.lines -eq 0)
                {
                    remove-item -force $f.fullname
                }  
            }
         }
    }
    
    

}



ProcessFile $path
ProcessArchive $path
DeleteEmptyFolder $path 2


