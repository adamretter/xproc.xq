(:
: Licensed under the Apache License, Version 2.0 (the "License");
: you may not use this file except in compliance with the License.
: You may obtain a copy of the License at
:
: http://www.apache.org/licenses/LICENSE-2.0
:
: Unless required by applicable law or agreed to in writing, software
: distributed under the License is distributed on an "AS IS" BASIS,
: WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
: See the License for the specific language governing permissions and
: limitations under the License.
:)

xquery version "1.0-ml" encoding "UTF-8";

(: ------------------------------------------------------------------------------------- 
 
	util.xqy - contains most of the XQuery processor specific functions, including all
	helper functions.
	
---------------------------------------------------------------------------------------- :)

module namespace u = "http://xproc.net/xproc/util";

declare namespace p="http://www.w3.org/ns/xproc";
declare namespace c="http://www.w3.org/ns/xproc-step";
declare namespace err="http://www.w3.org/ns/xproc-error";
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";
declare namespace xproc = "http://xproc.net/xproc";
declare namespace std = "http://xproc.net/xproc/std";
declare namespace opt = "http://xproc.net/xproc/opt";
declare namespace ext = "http://xproc.net/xproc/ext";
declare namespace xxq-error = "http://xproc.net/xproc/error";

import module namespace const = "http://xproc.net/xproc/const" at "/xquery/core/const.xqy";
import module namespace mem = "http://xqdev.com/in-mem-update"
    at "/MarkLogic/appservices/utils/in-mem-update.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare copy-namespaces no-preserve, no-inherit;

(: declare option xdmp:output "method=xml";
declare option xdmp:output "encoding=UTF8";
declare option xdmp:output "indent=yes";
:)

(:~ set to 1 to enable debugging :)
declare variable $u:NDEBUG := $const:NDEBUG;

declare variable $u:inputMap as map:map := map:map();

declare option xdmp:update "true";

(: -------------------------------------------------------------------------- :)
(:~ Processor Specific                                                         :)
(: -------------------------------------------------------------------------- :)


declare function u:ns-axis($el){
    $el/namespace::*
};

declare function u:document-get($path){
xdmp:document-get( $const:module_root || $path,<options xmlns="xdmp:document-get">
           <repair>full</repair>
           <format>xml</format>
       </options>)
};

declare function u:modules-root(){
    xdmp:modules-root()
};    

declare function u:value($primary,$test){
    $primary/xdmp:value( $test) 
};

declare function u:random(
  $seed as xs:integer
){
 xdmp:random($seed)
};

declare function u:episode() as xs:unsignedLong{
 xdmp:random()
};

declare function u:get-episode(){
    string(xdmp:get-server-field("p:episode"))
};

declare function u:set-episode(
    $episode as xs:unsignedLong
){
    xdmp:set-server-field("p:episode",$episode)
};

declare function u:startMap($episode){
    u:set-episode($episode)
};

declare function u:stopMap(){
(    (),
    xdmp:set-server-field("p:episode",()))
};

declare function u:putInputMap(
  $key as xs:string,
  $value as item()*
) as item()*
{
  try{ 
    if($value) then
    xdmp:eval('
        import module namespace u = "http://xproc.net/xproc/util" at "/xquery/core/util.xqy";

        declare option xdmp:update "true";

        declare variable $value external;
        declare variable $key external;

        let $uri := "/xproc/" || u:get-episode() || "/" || $key || ".xml"
        return  
        xdmp:document-insert($uri,
        <u:root episode="{u:get-episode()}">{
        for $v in $value
        return <u:entry id="{$key}">{$v}</u:entry>
        }</u:root>,(),("xproc"))',
        (fn:QName("","value"),$value,
         fn:QName("","key"), $key))
    else ()
    }catch($e){ if ($e/error:code eq "XDMP-ARG") then xdmp:log("problem with: " || $key ) else xdmp:rethrow() }

};

declare function u:getInputMap(
  $key as xs:string
)
{if (doc-available("/xproc/" || u:get-episode() || "/" || $key || ".xml")) then
    collection("xproc")/u:root[@episode eq u:get-episode()]//u:entry[@id eq $key]/*
else ()
};

declare function u:getAllResult()
{
    xdmp:log(u:get-episode()),
    for $d in collection("xproc")//u:root[@episode eq u:get-episode()]/u:entry
    order by $d/@id
    return $d
};

declare function u:getResult()
{
    collection("xproc")/u:root[@episode eq u:get-episode()]/u:entry[@id eq $const:final_id]/*
};

declare function u:getInterimResult($id)
{
    collection("xproc")/u:root[@episode eq u:get-episode()]/u:entry[@id eq $const:final_id]/*
};

declare function u:strip-whitespace($xml){
let $template := <xsl:stylesheet version="2.0">
<xsl:strip-space elements="*"/> 

<xsl:template match="element()">
  <xsl:copy>
    <xsl:apply-templates select="@*,node()"/>
   </xsl:copy>
</xsl:template>

<xsl:template match="attribute()|comment()|processing-instruction()">
  <xsl:copy/>
</xsl:template>
    
<xsl:template match="text()">
    <xsl:value-of select="normalize-space(.)"/>
</xsl:template>

</xsl:stylesheet>
return
  u:transform($template,$xml)
};

declare function u:string-to-base64($string as xs:string){
  () (:saxon:string-to-base64Binary($string, "UTF8") :)
};

(: -------------------------------------------------------------------------- :)
declare function u:store($href as xs:string,$data as item()){
(: -------------------------------------------------------------------------- :)
let $result := () (:saxon:result-document($href, $data, <xsl:output method="xml"/>) :)
return
  $href
};

(: -------------------------------------------------------------------------- :)
declare function u:parse($data as xs:string) as item(){
(: -------------------------------------------------------------------------- :)
() (: saxon:parse($data) :)
};


(: -------------------------------------------------------------------------- :)
declare function u:serialize($xml) as xs:string{
(: -------------------------------------------------------------------------- :)
$xml
(:
saxon:serialize($xml, <xsl:output method="xml" 
                             omit-xml-declaration="yes" 
                             indent="no"/>) 
:)
};

declare function u:log($info) {
xdmp:log($info)
};
  
(: -------------------------------------------------------------------------- :)
declare function u:dirlist($path){
(: -------------------------------------------------------------------------- :)
collection(concat($path,"?select=*.*;recurse=yes;on-error=ignore"))
};

(: -------------------------------------------------------------------------- :)
declare function u:result-document($href as xs:string, $doc as item()){
(: -------------------------------------------------------------------------- :)
let $writelog :=  () (:saxon:result-document($href, $doc, <xsl:output method="xml" indent="yes"/>) :)
return
  $href
};

declare function u:binary-doc($uri){
()
};

declare function u:binary-to-string($data){
()
};

(: -------------------------------------------------------------------------- :)
declare function u:serialize($xml,$options){
(: -------------------------------------------------------------------------- :)
$xml
};


(: -------------------------------------------------------------------------- :)
(: EVAL UTILITIES                                                             :)
(: -------------------------------------------------------------------------- :)

(: -------------------------------------------------------------------------- :)
declare function u:evalXPATH($xpath, $xml){
(: -------------------------------------------------------------------------- :)
 let $document := document{$xml}
 return
  if ($xpath eq '/' or $xpath eq '' or empty($xml)) then
    $document
  else
    u:xquery($xpath,$xml)
};


(: -------------------------------------------------------------------------- :)
declare function u:evalXPATH($xpath, $xml, $options){
(: -------------------------------------------------------------------------- :)
 let $document := document{$xml}
 return
  if ($xpath eq '/' or $xpath eq '' or empty($xml)) then
    $document
  else
    u:xquery($xpath,$xml,$options)
};


(: -------------------------------------------------------------------------- :)
declare function u:xquery($query, $xml, $options){
(: -------------------------------------------------------------------------- :)
 let $o := for $option in $options 
 let $value as xs:string := if($option/@select ne'') then string($option/@select) else concat('&quot;',$option/@value,'&quot;')
 return
   concat(' declare variable $',$option/@name,' := ',$value,';')
 let $q :=  concat($o,' ',$query)
 return
   u:xquery($q,$xml)
};


(: -------------------------------------------------------------------------- :)
declare function u:xquery($query, $xml){
(: -------------------------------------------------------------------------- :)
 let $context := document{$xml}       
 let $compile  :=  concat($const:default-ns,string($query))
 return
      if (string-length($query) lt 2) then u:xprocxqError("EMPTY-INPUT","required query input is empty") else $xml/xdmp:value( normalize-space($query) ) 
};


declare function u:evalPath($path as xs:string, $xml as node()*) as 
node()*
{
   u:evalPathImpl(tokenize($path, "/"), $xml)
};

declare function u:evalPathImpl($steps as xs:string*, $xml as 
node()*) as node()*
{
   if(empty($steps)) then $xml
   else if($steps[1] = "") then u:evalPathImpl(subsequence($steps, 
2), $xml/root())
   else if(starts-with($steps[1], "@")) then 
u:evalPathImpl(subsequence($steps, 2), $xml/@*[name() = 
substring($steps[1], 2)])
   else u:evalPathImpl(subsequence($steps, 2), $xml/*[name() = 
$steps[1]])
};


(: -------------------------------------------------------------------------- :)
declare function u:transform($stylesheet,$xml){
(: -------------------------------------------------------------------------- :)
    if ($xml instance of document-node())
    then xdmp:xslt-eval($stylesheet, $xml )
    else xdmp:xslt-eval($stylesheet, document{$xml} ) 
};

(: -------------------------------------------------------------------------- :)
declare function u:transform($stylesheet,$xml,$data){
(: -------------------------------------------------------------------------- :)
u:transform($stylesheet, $xml )
};


(: -------------------------------------------------------------------------- :)
(: STEP UTILITIES                                                             :)
(: -------------------------------------------------------------------------- :)


(: -------------------------------------------------------------------------- :)
declare function u:outputResultElement($exp){
(: -------------------------------------------------------------------------- :)
    element c:result{
        $exp
    }
};

(: -------------------------------------------------------------------------- :)
declare function u:get-secondary($name as xs:string,$secondary as element(xproc:input)*) as item()*{
(: -------------------------------------------------------------------------- :)
 document{  $secondary[@port eq $name]/node() }
};


(: -------------------------------------------------------------------------- :)
declare function u:get-eval-option($option-name as xs:string,$options as element(xproc:options),$primary) as xs:string{
(: -------------------------------------------------------------------------- :)
let $xpath as xs:string := string($options//p:with-option[@name eq $option-name]/@select)
return
if(starts-with($xpath,'&quot;') and ends-with($xpath,'&quot;')) then 
  concat('&quot;',$xpath,'&quot;')
else
string(u:evalXPATH($xpath,$primary,$options[@name]))
};

(: -------------------------------------------------------------------------- :)
declare function u:get-string-option($option-name as xs:string,$options as element(xproc:options),$primary) as xs:string{
(: -------------------------------------------------------------------------- :)
let $xpath as xs:string := string($options//p:with-option[@name eq $option-name]/@select)
return
  $xpath
};

(: -------------------------------------------------------------------------- :)
declare function u:get-option($option-name as xs:string,$options as element(xproc:options)?,$primary) as xs:string{
(: -------------------------------------------------------------------------- :)
let $xpath as xs:string := string($options//p:with-option[@name eq $option-name]/@select)
return
if(starts-with($xpath,'&quot;') and ends-with($xpath,'&quot;')) then 
 substring($xpath, 2, string-length($xpath) - 1)
else if ( starts-with($xpath,'http') or starts-with($xpath,'file')) then 
  replace($xpath,"'","")
else 
  replace($xpath,"'","")

(:string(
  u:evalXPATH($xpath,$primary,$options[@name])
):)

};





(: -------------------------------------------------------------------------- :)
(: ERROR HANDLING                                                             :)
(: -------------------------------------------------------------------------- :)


(: -------------------------------------------------------------------------- :)
declare function u:xprocxqError($code,$string) {
(: -------------------------------------------------------------------------- :)
let $info := $const:xprocxq-error//xxq-error:error[@code=substring-after($code,':')]
    return
        error(QName('http://xproc.net/xproc/error',$code),concat("xprocxq error - ",$string," ",$info/text()))};




(: -------------------------------------------------------------------------- :)
declare function u:dynamicError($error,$string) {
(: -------------------------------------------------------------------------- :)
    let $info := $const:error//err:error[@code=substring-after($error,':')]
    return
        error(QName('http://www.w3.org/ns/xproc-error',$error),concat($error,": XProc Dynamic Error - ",$string," ",$info/text(),'&#10;'))
};

(: -------------------------------------------------------------------------- :)
declare function u:stepError($error,$string) {
(: -------------------------------------------------------------------------- :)
let $info := $const:error//err:error[@code=substring-after($error,':')]
    return
        error(QName('http://www.w3.org/ns/xproc-error',$error),concat($error,": XProc Step Error - ",$string," ",$info/text(),'&#10;'))
};




(: -------------------------------------------------------------------------- :)
(: ASSERTIONS, DEBUG TOOLS                                                    :)
(: -------------------------------------------------------------------------- :)

(: -------------------------------------------------------------------------- :)
declare function u:trace($value as item()*, $what as xs:string)  {
if(boolean($const:NDEBUG)) then
    trace($value,$what)
else
    ()
};


(: -------------------------------------------------------------------------- :)
declare function u:asserterror($errortype as xs:string, $booleanexp as item(), $why as xs:string)  {
if(not($booleanexp) and boolean($const:NDEBUG)) then
    u:dynamicError(fn:QName('http://www.w3.org/ns/xproc-error',$errortype),$why)
else
    ()
};


(: -------------------------------------------------------------------------- :)
declare function u:assert($booleanexp as item(), $why as xs:string)  {
if(not($booleanexp) and boolean($const:NDEBUG)) then 
    u:dynamicError('err:XC0020',$why)
else
    ()
};


(: -------------------------------------------------------------------------- :)
declare function u:assert($booleanexp as item(), $why as xs:string,$error)  {
(: -------------------------------------------------------------------------- :)
if(not($booleanexp) and boolean($u:NDEBUG)) then 
    error(QName('http://www.w3.org/ns/xproc-error',$error),concat("XProc Assert Error: ",$why))
else
    ()
};


(: -------------------------------------------------------------------------- :)
(: manage namespaces                                                          :)
(: -------------------------------------------------------------------------- :)

declare function u:declarens($element){
    u:declare-ns(u:enum-ns($element))
};


declare function u:declare-ns($namespaces){
    for $ns in $namespaces//ns
    return
        ()
};


declare function u:namespaces-in-use( $root as node()? )  {
let $element := if ($root instance of document-node()) then $root/* else $root       
for $ns in distinct-values($element/descendant-or-self::*/(.)/in-scope-prefixes(.))
    return
    if($ns eq 'xml' or $ns eq '')
    then () 
    else <ns prefix="{$ns}" URI="{namespace-uri-for-prefix($ns,$element)}"/>
} ;

declare function u:enum-ns($element){
       for $child in $element/node()
            return
              if ($child instance of element() or $child instance of document-node()) then
               	 u:namespaces-in-use($child)
                else
                  ()
};


(:
declare function u:xquery($query as xs:string){
    let $qry := if (starts-with($query,'/') or starts-with($query,'//')) then
                concat('.',$query)
			  else if(contains($query,'(/')) then
				replace($query,'\(/','(./')
              else if($query eq '') then
			    u:dynamicError('err:XD0001','query is empty and/or XProc step is not supported')
              else
                  $query
    let $result := util:eval($qry)   
    return
        $result
};


:)
