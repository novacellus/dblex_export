<?xml version="1.0" encoding="UTF-8"?>
<p:declare-step xmlns:p="http://www.w3.org/ns/xproc" xmlns:c="http://www.w3.org/ns/xproc-step"
    version="3.0" xmlns="http://www.tei-c.org/ns/1.0">

    <p:input port="source" primary="true" sequence="true"/>
    <p:output port="result" primary="true" sequence="true">
        <p:empty/>
    </p:output>

    <!-- file folder -->
    <p:variable name="in_directory" select="'1-1'"/>
    <!-- folder to process -->
    <p:variable name="folder_path"
        select="'file:/C:/Users/user/Desktop/rekoncyliacja_SGP/MorganaXProc-IIIse-1.3.10/MorganaXProc-IIIse-1.3.10/'"/>
    <p:variable name="in_dir" select="concat($folder_path,$in_directory)"/>

    <!--<p:option name="in_dir" select="'./segmentacja/segmentacja/SGP/1-2'"/>-->
    <p:variable name="abbr" select="tokenize($in_dir,'/')[last()]" expand-text="true"/>

    <!-- read in file list -->
    <p:directory-list name="list_dir" include-filter=".*xml" exclude-filter="0merged.xml"
        message="Listing files in the directory {$in_dir}">
        <p:with-option name="path" select="$in_dir"/>
    </p:directory-list>

    <p:for-each name="files" message="Load files in alphabetical order">
        <!-- sort files alphabetically -->
        <p:with-input select="sort(//c:file, (), function($f) {$f/@name})"/>
        <p:variable name="current-file" select="c:file/@name"/>
        <p:load content-type="application/xml" name="load-file">
            <p:with-option name="href" select="resolve-uri(c:file/@name, base-uri(.))"/>
            <!--<p:with-option name="href" select="resolve-uri(c:file/@name, $in_dir)"/>-->
        </p:load>

        <p:insert match="*:body/*:entryFree[1]" position="first-child" message="Inserting pb to
            {count(//*:body/*)}">
            <p:with-input port="source" select="."/>
            <p:with-input port="insertion">
                <pb n="{$current-file}"/>
            </p:with-input>
        </p:insert>
        <p:store>
            <p:with-input port="source" select="."/>
            <!-- Generate a valid file name using the document's original name -->
            <p:with-option name="href" select="concat('/tmp/xproc/', $current-file)"/>
        </p:store>
    </p:for-each>

    <p:wrap-sequence wrapper="all"/>
    <p:filter select="(//*:body/*)"/>
    <p:wrap-sequence wrapper="body" message="Wrap sequence in body element"/>
    <!-- apply XSL transformation -->
    <p:xslt message="Apply transformation to merge files">
        <p:with-input port="stylesheet" href="./WrapTEI.xsl"/>
        <p:with-option name="parameters" select="map {'dir' : $abbr}"/>
    </p:xslt>

    <p:xslt message="Apply formatting stylesheet">
        <p:with-input port="stylesheet" href="./formatTEI.xsl"/>
        <!--<p:with-option name="parameters" select="map {'dir' : $abbr}"/>-->
    </p:xslt>

    <p:store message="Storing merged file as {$abbr}_merged.xml">
        <p:with-option name="href" select="concat($abbr, '_merged.xml')"/>
    </p:store>

</p:declare-step>
