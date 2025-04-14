<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    exclude-result-prefixes="xs math" 
    version="3.0">
    <xsl:output method="xml" indent="yes" />
    <xsl:mode name="groupEntries" on-no-match="shallow-copy"/>
    <xsl:mode name="groupSubEntries" on-no-match="shallow-copy"/>
    <xsl:mode name="groupPunctuation" on-no-match="shallow-copy"/>
    <xsl:mode name="groupPunctuationSecond" on-no-match="shallow-copy"/>
    <xsl:mode name="groupOverlaps" on-no-match="shallow-copy"/>
    <xsl:mode on-no-match="shallow-copy" name="namespace"/>
    <xsl:param name="dir" required="yes"/>   
    <xsl:template match="*:body">
            <xsl:variable name="groupEntries">
                <xsl:apply-templates select="." mode="groupEntries"/>
            </xsl:variable>
        <xsl:variable name="groupSubEntries">
            <xsl:apply-templates select="$groupEntries" mode="groupSubEntries"/>
        </xsl:variable>
        <xsl:variable name="groupPunctuation">
            <xsl:apply-templates select="$groupSubEntries" mode="groupPunctuation"/>
        </xsl:variable>
        <xsl:variable name="groupPunctuationSecond">
            <xsl:apply-templates select="$groupPunctuation" mode="groupPunctuationSecond"/>
        </xsl:variable>
        <xsl:variable name="groupOverlaps">
            <xsl:apply-templates select="$groupPunctuationSecond" mode="groupOverlaps"/>
        </xsl:variable>
        <xsl:variable name="namespace">
            <xsl:apply-templates select="$groupOverlaps" mode="namespace"/>
        </xsl:variable>
        <!--<xsl:copy-of select="$namespace"/>-->
        <xsl:copy-of select="$namespace"/>
    </xsl:template>
    
    <!-- delete empty author initials 
    <persName type="initial" role="entry-author"/>
    -->
    <xsl:template match="*:persName[@role='entry_author'][normalize-space(.) eq '']" mode="groupPunctuation"/>
    
    <!-- group continued elements of entries -->
    <xsl:template name="addAttr">
        <xsl:param name="content"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:for-each-group select="*" group-starting-with="*:milestone[@subtype='continued-entry']">
                <xsl:choose>
                    <xsl:when test="current-group()[1][self::*:milestone[@subtype='continued-entry']]">
                        <xsl:copy select="current-group()[2]">
                            <xsl:copy-of select="@*"/>
                            <xsl:attribute name="type" select="'continued'"/>
                            <xsl:apply-templates select="node()|text()"
                                mode="#current"/>
                        </xsl:copy>
                        <xsl:apply-templates select="current-group()[position() &gt; 2]"
                            mode="#current"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="current-group()"
                            mode="#current"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="*[name()='sense' or
        name()='quote'][following-sibling::*[1][self::*:milestone[@subtype='continued-entry']]]" mode="groupOverlaps">
        <xsl:element name="{name()}">
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates select="node()" mode="#current"/>
            
            <!-- Get the corresponding element after the milestone -->
            <xsl:variable name="next-element" select="following-sibling::*[2][name()=name(current())]"/>
            <xsl:if test="$next-element">
                <xsl:apply-templates mode="#current" select="$next-element/node()"/>
            </xsl:if>
        </xsl:element>
    </xsl:template>
    
    <xsl:template
        match="*[name()='cit'][descendant::*[self::*:quote]][following-sibling::*[1][self::*:milestone[@subtype='continued-entry']]][following-sibling::*[2][name()
        = 'cit'][not(descendant::*[self::*:quote])]]"
        mode="groupOverlaps">
        <xsl:element name="{name()}">
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates select="node()" mode="#current"/>
            
            <!-- Get the corresponding element after the milestone -->
            <xsl:variable name="next-element" select="following-sibling::*[2][name()=name(current())]"/>
            <xsl:if test="$next-element">
                <xsl:apply-templates mode="#current" select="$next-element/node()"/>
            </xsl:if>
        </xsl:element>
    </xsl:template>
    
    <xsl:template mode="groupOverlaps"
        match="*:usg[.//*:settlement][following-sibling::*[1][self::*:milestone[@subtype='continued-entry']]][following-sibling::*[2][self::*:usg[.//*:region]]]">
        <usg>
            <xsl:copy-of select="@*"/>
            <xsl:apply-templates select="node()" mode="#current"/>
            <xsl:apply-templates select="following-sibling::*[2][self::*:usg]/node()" mode="#current"/>
        </usg>
    </xsl:template>
    <!--*[name()='cit'][descendant::*[self::*:quote]][following-sibling::*[1][self::*:milestone[@subtype='continued-entry']]][following-sibling::*[2][name()
    = 'cit'][not(descendant::*[self::*:quote])]]-->
    <xsl:template mode="groupOverlaps" match="*[name()
        =
        'cit'][not(descendant::*[self::*:quote])][preceding-sibling::*[1][self::*:milestone[@subtype='continued-entry']]][preceding-sibling::*[2][name()='cit'][descendant::*[self::*:quote]]]"/>
    <xsl:template mode="groupOverlaps" match="*[name()='sense' or
        name()='quote'][preceding-sibling::*[1][self::*:milestone[@subtype='continued-entry']]][name()=name(preceding-sibling::*[2])]"/>
    <xsl:template mode="groupOverlaps"
        match="*[self::*:usg[.//*:region]][preceding-sibling::*[1][self::*:milestone[@subtype='continued-entry']]][preceding-sibling::*[2][self::*:usg[.//*:settlement]]]"/>
    
    <xsl:template match="*:milestone[@subtype='continued-entry']" mode="groupOverlaps"/>
    
       <xsl:template match="*:body" mode="groupEntries">
        <xsl:element name="body">
        <xsl:for-each-group select="*"
            group-starting-with="*:entryFree[descendant::*:form[@type='lemma']|descendant::*:orth[@type='lemma']]">  
            <xsl:choose>
                <xsl:when
                    test="current-group()[1][self::*:entryFree[descendant::*:form[@type='lemma']|descendant::*:orth[@type='lemma']]]">
                    <xsl:element name="entryFree">
                        <xsl:attribute name="xml:id" select="concat('entry_', generate-id())"/>
                          <xsl:copy-of select="current-group()[1]/@*" />
                                <xsl:for-each select="current-group()">
                                    <xsl:if test="self::*:entryFree">
                                    <xsl:if test="position() &gt; 1">
                                        <xsl:element name="milestone">
                                            <xsl:attribute name="subtype"
                                                select="'continued-entry'"/>
                                        </xsl:element>
                                    </xsl:if>                                        
                                    <xsl:apply-templates select="node()|text()" mode="groupEntries"/>
                                    </xsl:if>
                                    <xsl:if test="not(self::*:entryFree)">
                                        <xsl:apply-templates mode="groupEntries"/>
                                    </xsl:if>
                                </xsl:for-each>                                
                            </xsl:element>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:apply-templates select="current-group()" mode="groupEntries"/>
                        </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each-group>
        </xsl:element>
    </xsl:template>
   
   <xsl:template match="*:def" mode="groupEntries">
       <xsl:copy>
           <xsl:copy-of select="@*"/>
           <xsl:attribute name="xml:id" select="concat('def_', generate-id())"/>
           <xsl:apply-templates mode="groupEntries"/>
       </xsl:copy>
   </xsl:template>
    
    <!-- group subentries -->
    
    <xsl:template match="*:entryFree" mode="groupSubEntries">
        <xsl:element name="entryFree">
            <xsl:copy-of select="@*"/>
            <xsl:for-each-group select="*"
                group-starting-with="*:form[@type='sublemma']"> 
                <xsl:choose>
                    <xsl:when
                        test="current-group()[1][self::*:form[@type='sublemma']]">
                        <xsl:element name="entryFree">
                            <xsl:attribute name="type" select="'relatedEntry'"/>
                            <xsl:attribute name="xml:id" select="concat('entry_', generate-id())"/>
                            <!--<xsl:copy-of select="current-group()[1]/@*" />-->
                            <xsl:apply-templates select="current-group()" mode="groupSubEntries"/>
                        </xsl:element>
                    </xsl:when>
                    <xsl:otherwise>                         
                        <xsl:copy-of select="current-group()"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>
        </xsl:element>
    </xsl:template>
   
    <!-- group trailing punctuation -->
    <xsl:template name="append-child">
        <xsl:param name="node"/>
        <xsl:param name="child"/>
        <xsl:copy select="$node">
            <xsl:for-each select="$node/*|text()[normalize-space(.) ne '']">
                <xsl:apply-templates select="." mode="#current"/>
            </xsl:for-each>
            <xsl:copy-of select="$child"/>
        </xsl:copy>
    </xsl:template>

    <!--<xsl:call-template name="append-child">
                                    <xsl:with-param name="child" select="current-group()[last()]"/>
                                    <xsl:with-param name="node" select="current-group()[last()-1]"/>
                                </xsl:call-template>-->
    
    <xsl:template match="*" mode="groupPunctuation">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:for-each-group select="*|text()[normalize-space(.) ne'']"
                group-ending-with="*:pc"> 
                    <xsl:choose>
                        <xsl:when
                        test="current-group()[last()][self::*:pc] and current-group()[last()-1][self::*:sense | self::*:cit | self::*:entryFree | self::*:def]">
                            <xsl:for-each select=".">
                                <xsl:apply-templates select="current-group()[position() &lt;
                                    last()-1]" 
                                    mode="groupPunctuation"/>
                            </xsl:for-each>
                                <xsl:call-template name="append-child">
                                    <xsl:with-param name="child" select="current-group()[last()]"/>
                                    <xsl:with-param name="node" select="current-group()[last()-1]"/>
                                </xsl:call-template>
                                <!--<xsl:apply-templates select="current-group()[position &lt; last()-1]"/>-->
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:for-each select="current-group()">
                            <xsl:apply-templates select="." 
                                mode="groupPunctuation"/>
                        </xsl:for-each>   
                    </xsl:otherwise>
                    </xsl:choose>
            </xsl:for-each-group>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="*" mode="groupPunctuationSecond">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:for-each-group select="*|text()[normalize-space(.) ne'']"
                group-ending-with="*:pc"> 
                <xsl:choose>
                    <xsl:when
                        test="current-group()[last()][self::*:pc] and current-group()[last()-1][self::*:sense | self::*:cit | self::*:entryFree | self::*:def]">
                        <xsl:for-each select="current-group()[position() &lt;
                            last()-1]">
                            <xsl:apply-templates select="." 
                                mode="groupPunctuationSecond"/>
                        </xsl:for-each>
                                                   
                        <xsl:call-template name="append-child">
                            <xsl:with-param name="child" select="current-group()[last()]"/>
                            <xsl:with-param name="node" select="current-group()[last()-1]"/>
                        </xsl:call-template>
                        <!--<xsl:apply-templates select="current-group()[position &lt; last()-1]"/>-->
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:for-each select="current-group()">
                            <xsl:apply-templates select="." 
                                mode="groupPunctuationSecond"/>
                        </xsl:for-each>                      
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:for-each-group>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template mode="namespace" match="body">
        <TEI>
            <teiHeader>
                <fileDesc>
                    <titleStmt>
                        <title><xsl:value-of select="$dir"/>
                        </title>                        
                    </titleStmt>
                    <publicationStmt>
                        <p>Publication Information</p>
                    </publicationStmt>
                    <sourceDesc>
                        <p>Information about the source</p>
                    </sourceDesc>
                </fileDesc>
            </teiHeader>
            <text>
                <body>
                    <xsl:apply-templates mode="namespace"/>
                </body>
            </text>
        </TEI>
    </xsl:template>
</xsl:stylesheet>