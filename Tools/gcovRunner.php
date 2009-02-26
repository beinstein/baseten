<?php
//
//  gcovRunner.php
//  Created by Nikita Zhuk on Nov 18 2006.
//  Copyright (c) 2006 Marko Karppinen & Co. LLC. All rights reserved.
//
//  $Id$

/*
	This script generates a coverage report from Objective-C and C source files which have been compiled with gcov support. 
	Coverage report can be then output as a simple text dump or as a CSV file. 

	Script generates .gcov files into the given object file directory by using gcov-4.0 tool. Sources must be compiled & linked with the following GCC flags:
	 -ftest-coverage -fprofile-arcs -lgcov

    Command line arguments:
		- Output format ('txt' / 'csv').
		- Full paths of the source file directories
        - Full path of the object file directory
*/

if(count($argv) < 3) die("Pass the full path(s) of the source file directory/directories and the full path of the object file directory as command line arguments\n");

$format = $argv[1];
if($format != 'txt' && $format != 'csv')
{
	echo "WARNING: Unsupported output format '$format', using 'txt'.";
	$format = 'txt';
}

$srcDirs = array_slice($argv, 2, count($argv)-3);
$srcDirs = array_map(realpath, $srcDirs);

$objDir = $argv[count($argv)-1];
if(!is_dir($objDir)) die("Object file directory '$objDir' isn't a directory\n");
$objDir = realpath($objDir);

chdir($objDir);

$analyzedSourceFileExtensions = array("m", "mm", "c", "cpp");
$coverageInfos = array();

foreach($srcDirs as $srcDir)
{
	$srcDir = realpath($srcDir);
	if(!is_dir($srcDir)) die("Source file directory '$srcDir' isn't a directory\n");

	if ($dh = opendir($srcDir))
	{
		while (($file = readdir($dh)) !== false)
		{
		    foreach($analyzedSourceFileExtensions as $fileExtension)
		    {
	    		if(filename_extension($file) == $fileExtension)
	    		{
	    			$coverageInfo = countCoverage($file, $srcDir, $objDir);
	    			if($coverageInfo)
	    			{
	    			    $coverageInfos[] = $coverageInfo;
				    }
				    else
				    {
				        fwrite(STDERR, "Skipped '$file'\n");
				    }
	    		}
		    }
	   }
   
	   closedir($dh);
	}	
}

uasort($coverageInfos, "coverageCompare");

if($format == 'csv')
    generate_output_csv($coverageInfos);
else
    generate_output_txt($coverageInfos);


function generate_output_csv($coverageInfos)
{
    $csvDelimiter = ';';
	
    $functionCoverageValues = CoverageInfo::getFunctionCoverageValues($coverageInfos);
    $lineCoverageValues = CoverageInfo::getLineCoverageValues($coverageInfos);
    $lineCoverageWeightedAverage = CoverageInfo::getLineCoverageWeightedAverage($coverageInfos);
    $effectiveLinesSum = CoverageInfo::getEffectiveLinesSum($coverageInfos);

    echo "Report generated $csvDelimiter" . date("H:i d.m.Y") . "\n\n";

    printf("Line coverage average, weighted by effective lines of code %s %s %.2f\n", '%', $csvDelimiter,  round($lineCoverageWeightedAverage, 2));
	printf("Line coverage deviation %s %s %.2f\n", '%', $csvDelimiter, round(standardDeviation($lineCoverageValues), 2));
	printf("Function coverage average %s %s %.2f\n", '%', $csvDelimiter, round(average($functionCoverageValues), 2));
	printf("Function coverage deviation %s %s %.2f\n", '%', $csvDelimiter, round(standardDeviation($functionCoverageValues), 2));
	printf("Total effective lines of code %s %d\n\n", $csvDelimiter, $effectiveLinesSum);

    echo "Line coverage % $csvDelimiter Function coverage % $csvDelimiter Effective lines of code $csvDelimiter Compilation unit\n";
    
    foreach($coverageInfos as $coverageInfo)
    {
    	printf("%10.2f%s%10.2f%s%6d%s%s\n", $coverageInfo->lineCoverage, $csvDelimiter, $coverageInfo->functionCoverage, $csvDelimiter, $coverageInfo->effectiveLines, $csvDelimiter, $coverageInfo->name);
    }
}	

function generate_output_txt($coverageInfos)
{
    $functionCoverageValues = CoverageInfo::getFunctionCoverageValues($coverageInfos);
    $lineCoverageValues = CoverageInfo::getLineCoverageValues($coverageInfos);
    $lineCoverageWeightedAverage = CoverageInfo::getLineCoverageWeightedAverage($coverageInfos);
    $effectiveLinesSum = CoverageInfo::getEffectiveLinesSum($coverageInfos);

    echo "Report generated " . date("H:i d.m.Y") . "\n\n";
    printf("Line coverage average, weighted by effective lines of code %s: %.2f\n", '%', round($lineCoverageWeightedAverage, 2));
	printf("Line coverage deviation %s: %.2f\n", '%', round(standardDeviation($lineCoverageValues), 2));
	printf("Function coverage average %s: %.2f\n", '%', round(average($functionCoverageValues), 2));
	printf("Function coverage deviation %s: %.2f\n", '%', round(standardDeviation($functionCoverageValues), 2));
	printf("Total effective lines of code: %d\n\n", $effectiveLinesSum);

	printf("%10s\t%10s\t%6s\t%s\n", "LineCov%", "FuncCov%", "ELOC", "Name\n");

    foreach($coverageInfos as $coverageInfo)
    {
    	printf("%10.2f\t%10.2f\t%6d\t%s\n", $coverageInfo->lineCoverage, $coverageInfo->functionCoverage, $coverageInfo->effectiveLines, $coverageInfo->name);
    }
}	
	
function coverageCompare($a, $b)
{
	if ($a->lineCoverage == $b->lineCoverage)
	{
        if($a->functionCoverage < $b->functionCoverage)
            return 1;
        else if($a->functionCoverage > $b->functionCoverage)
            return -1;
        else
            return 0;
   }
   
   return ($a->lineCoverage < $b->lineCoverage) ? 1 : -1;
}

function countCoverage($sourceFileName, $srcDir, $objDir)
{
	$lines = 0;
	$coveredLines = 0;
	$nonCoveredLines = 0;
	$ignoredLines = 0;
	$coveredFunctions = 0;
	$nonCoveredFunctions = 0;

    $sourceFilePath = $srcDir . '/' . $sourceFileName;
	$output = array();
    $gcovFilePath = "";

    $cmd = "gcov-4.0 -f -o " . escapeshellarg($objDir) . ' ' . escapeshellarg($sourceFilePath);
	exec($cmd, $output);

    for($i = 0; $i < count($output); $i++)
    {
        //FIXME: when does this happen?
        assert (false ===  (strpos ($output [$i], "##")));

        $matches = array();
	    if(strpos($output[$i], "Function '") === 0)
	    {
	        $offset = strlen("Lines executed:");
            $lineCoverageOfFunction = substr($output[$i+1], $offset, strpos($output[$i+1], "%", $offset)-$offset);
            $i++;

            if($lineCoverageOfFunction > 0)
                $coveredFunctions++;
            else
                $nonCoveredFunctions++;
        }
        else if (preg_match ("/^.+\/([^\/]+):creating\s+'(.+\.gcov)'$/", $output[$i], $matches))
        {
            if ($matches[1] == $sourceFileName)
                $gcovFilePath = $matches[2];
        }
    }
	
	if(count($output) == 0)
		return null;
		
    assert($gcovFilePath);
    $gcovFilePath = $objDir . '/' . $gcovFilePath;

    if(!is_file($gcovFilePath) || !file_exists($gcovFilePath))
	{
		echo "WARNING: GCov file not found from path '$gcovFilePath'.\n";
        return null;
    }

	$fh = fopen($gcovFilePath, "r");
	while (!feof($fh))
	{
   		$line = fgets($fh);
   		
   		$lines++;
		if(isLineIgnored($line))
			$ignoredLines++;
		else if(isLineNonCovered($line))
			$nonCoveredLines++;
		else
		{
			$coveredLines++;
		}
	}
	fclose($fh);

    $functionCount = $coveredFunctions + $nonCoveredFunctions;
	$gcovEffectiveLines = $nonCoveredLines + $coveredLines;
    $lineCoverage = ($lines-$ignoredLines) > 0 ? round(($coveredLines / ($lines-$ignoredLines)) * 100, 2) : 0;
    $functionCoverage = $functionCount > 0 ? round(($coveredFunctions / $functionCount) * 100, 2) : 0;
    $coverageInfo = new CoverageInfo($sourceFileName, $lineCoverage, $functionCoverage, $gcovEffectiveLines);
	
    return $coverageInfo;
}


function isLineIgnored($line)
{
	if(strpos($line, "        -:") === 0)
		return true;
		
	if(strlen(trim($line)) == 0)
	    return true;
	    
	return false;
}

function isLineNonCovered($line)
{
	if(strpos($line, "    #####:") === 0)
		return true;
	return false;
}

function standardDeviation($samples)
{
    $sample_count = count($samples);
    if($sample_count == 0)
        return 0;
        
    $sampleDeviationSum = 0;
    $average = average($samples);
    
    for ($i = 0; $i < $sample_count; $i++)
    {
        $sampleDeviationSum += pow($average - $samples[$i], 2);
    }
    
    $standard_deviation = sqrt($sampleDeviationSum / $sample_count);
    return $standard_deviation;
}

function average($samples)
{
   if (!is_array($samples)) return false;
   if(count($samples) == 0) return 0;
   
   return array_sum($samples)/count($samples);
}

function filename_extension($filename)
{
   $pos = strrpos($filename, '.');
   if($pos === false)
   {
       return false;
   }
   else
   {
       return substr($filename, $pos+1);
   }
}

class CoverageInfo
{
    var $name;
    var $lineCoverage;
    var $functionCoverage;
    var $effectiveLines;

    function CoverageInfo($name, $lineCoverage, $functionCoverage, $effectiveLines) 
    {
        $this->name = $name;
        $this->lineCoverage = $lineCoverage;
        $this->functionCoverage = $functionCoverage;
		$this->effectiveLines = $effectiveLines;
    }
    
    function getFunctionCoverageValues(&$coverageInfoArray)
    {
        $values = array();
        foreach($coverageInfoArray as $coverageInfo)
        {
            $values[] = $coverageInfo->functionCoverage;
        }
        
        sort($values);
        return $values;
    }

	function getEffectiveLinesSum(&$coverageInfoArray)
	{
		$effectiveLinesSum = 0;
		
        foreach($coverageInfoArray as $coverageInfo)
        {
            $effectiveLinesSum += $coverageInfo->effectiveLines;
        }

		return $effectiveLinesSum;
	}
	
    function getLineCoverageWeightedAverage(&$coverageInfoArray)
    {
        $values = array();
		$effectiveLinesSum = 0;
		$weightedLineCoverageSum = 0;
		
        foreach($coverageInfoArray as $coverageInfo)
        {
            $effectiveLinesSum += $coverageInfo->effectiveLines;
			$weightedLineCoverageSum += ($coverageInfo->lineCoverage * $coverageInfo->effectiveLines);
        }
		
		return ($effectiveLinesSum > 0) ? $weightedLineCoverageSum / $effectiveLinesSum : 0;
    }
    
    function getLineCoverageValues(&$coverageInfoArray)
    {
        $values = array();
        foreach($coverageInfoArray as $coverageInfo)
        {
            $values[] = $coverageInfo->lineCoverage;
        }
        
        sort($values);
        return $values;
    }

}
	
?>
