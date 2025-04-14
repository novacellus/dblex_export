<?xml version="1.0" encoding="UTF-8"?>
<!--
    Returns:
    _sparse.xml: sparse tree serialization
    _ definitions.csv: dictionary definitions (entry_id, definition id, definition string)
    _ entries.csv: dictionary entries (entry id, lemma, forms)

-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs"
    version="3.0">
       <xsl:strip-space elements="*"/>
    <xsl:mode on-no-match="shallow-skip" name="sparse_tree"/>
    <xsl:mode on-no-match="shallow-skip" name="entries"/>
    <xsl:mode on-no-match="shallow-skip" name="definitions"/>
    <xsl:output method="text" name="entries" encoding="UTF-8"/>
    <xsl:output method="text" name="definitions" encoding="UTF-8"/>
    <xsl:param name="filename"/>
    <xsl:template match="/">
        <!-- zredukowana perspektywa na hasło w 1. kroku -->
        <xsl:variable name="sparse_tree">
            <entries>
            <xsl:apply-templates mode="sparse_tree"/>
            </entries>
        </xsl:variable>
        <xsl:result-document href="{$filename}_entries.csv" format="entries">
            <xsl:value-of select="concat(
                'entry_id',     '&#009;',
                'entry_type',   '&#009;',
                'entry_n',      '&#009;',
                'empty_lbl',    '&#009;',
                'lemma',        '&#009;',
                'orth',         '&#xA;'
                )"/>
            <xsl:apply-templates mode="entries" select="$sparse_tree"/>
        </xsl:result-document>
        <xsl:result-document href="{$filename}_definitions.csv" format="definitions">
            <xsl:value-of select="concat(
                'sense_n', '&#009;',
                'sense_id', '&#009;',
                'parent_sense_id','&#009;',
                'parent_sense_collocs','&#009;',
                'parent_sense_usg','&#009;',
                'parent_sense_gram','&#009;',
                'entry_id', '&#009;', 
                'def_id', '&#009;', 
                'def', '&#xA;')"/>
            <xsl:apply-templates mode="definitions" select="$sparse_tree"/>
        </xsl:result-document>
        <xsl:result-document href="{$filename}_sparse.xml" indent="true" method="xml">
            <xsl:copy-of select="$sparse_tree"></xsl:copy-of>    
        </xsl:result-document>
        
    </xsl:template>
    
    <xsl:template match="*:sense"  mode="sparse_tree" priority="100">
        <xsl:variable name="parent-sense" select="if(parent::*:sense) 
            then (parent::*:sense/@xml:id) else ('')"/>
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="parent-sense" select="$parent-sense"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="*:sense/*:usg[not(@type='geo')]|*:sense/*:colloc|*:sense/gramGrp"  mode="sparse_tree">
        <xsl:copy> 
            <xsl:copy-of select="@*"/>
            <xsl:value-of select="normalize-space(.)"/>
        </xsl:copy>
    </xsl:template>
    
    <xsl:template match="*:sense/*:def"  mode="sparse_tree">
       <xsl:copy> 
           <xsl:copy-of select="@*"/>
        <!-- dodać numery -->
        <xsl:value-of select="normalize-space(.)"/>
       </xsl:copy>
    </xsl:template>
    
  
    
    <xsl:template match="*:teiHeader"/>
    <xsl:template match="*:entryFree" mode="sparse_tree">
        <xsl:variable name="number" select="if (*:form/*:n[1]) then (*:form/*:n[1]) else ()"/>
        <xsl:variable name="empty" select="if (*:form/lbl[@type eq 'emptyEntry']) then (*:form/lbl[@type eq 'emptyEntry']) else ()"/>
        <xsl:copy>
            <xsl:copy-of select="@xml:id|@type"/>
            <n><xsl:value-of select="$number"/></n>
            <empty_lbl><xsl:value-of select="$empty"/></empty_lbl>
            <xsl:for-each select=".//*:form[@type='lemma']|.//*:orth[@type='lemma']">
                <lemma>                    
                <xsl:if test="name(.) = 'form'">
                        <xsl:value-of select="*:orth"/>
                </xsl:if>
                <xsl:if test="name(.) = 'orth'">
                        <xsl:value-of select="."/>
                </xsl:if>
                </lemma>
            </xsl:for-each>
           
            <xsl:apply-templates mode="#current"/>        
            <xsl:for-each select=".//*:form[not(@type='lemma')][not(child::*:orth[@type='lemma'])]">
                <orth>
                <xsl:if test="name(.) = 'form'">
                    <xsl:value-of select="*:orth"/>
                </xsl:if>
                <xsl:if test="name(.) = 'orth'">
                    <xsl:value-of select="."/>
                </xsl:if>
                </orth>
            </xsl:for-each>   
        </xsl:copy>
    </xsl:template>
    <xsl:template match="*:entryFree" mode="entries">
        <xsl:variable name="entry_id" select="@xml:id"/>
        <xsl:variable name="entry_n" select="n"/>
        <xsl:variable name="empty_lbl" select="empty_lbl"/>
        <xsl:variable name="entry_type">
            <xsl:if test="@type">
                <xsl:if test="$entry_n ne ''">
                    <xsl:if test="@type = ('xref', 'empty')">
                        <xsl:value-of select="string-join((@type, 'hom'),',')"/>
                    </xsl:if>
                    <xsl:if test="@type = 'hom'">
                        <xsl:text>hom</xsl:text>
                    </xsl:if>
                </xsl:if>
                <xsl:if test="$entry_n eq ''">
                    <xsl:value-of select="@type"/>
                </xsl:if>
            </xsl:if>
            <xsl:if test="not(@type)">
                <xsl:text>norm</xsl:text>
            </xsl:if>
        </xsl:variable>
        <xsl:variable name="lemmas">
            <xsl:value-of select="for $l in lemma return normalize-space($l)"/>
        </xsl:variable>
        <xsl:variable name="defs">
            <xsl:for-each select="def">
              <!--  <xsl:variable name="def_id" select="@xml:id"/>-->
                <xsl:value-of select="concat(@xml:id,'#',normalize-space(.))"/>                
            </xsl:for-each>
        </xsl:variable>
        <xsl:variable name="orths" as="text()*">
            <xsl:for-each select="orth">
                <xsl:value-of select="normalize-space(.)"/>
            </xsl:for-each>
        </xsl:variable>
        <xsl:value-of select="$entry_id"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$entry_type"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$entry_n"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$empty_lbl"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="string-join(
            for $l in lemma return normalize-space($l),
            ',')"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="string-join(
            (for $orth in $orths[normalize-space(.) ne ''] return normalize-space($orth)), ',')"/>
        <xsl:text>&#xA;</xsl:text>
      <!--  <xsl:text>&#009;</xsl:text> 
        <xsl:value-of select="string-join((for $def in $defs return concat($def/@xml:id,'#',$def)), ',')"/>-->
        <!--<xsl:value-of select="$row_els"/>-->
    </xsl:template>
    <xsl:template match="*:def" mode="definitions">
        <xsl:variable name="entry_id" select="ancestor::*:entryFree/@xml:id"/>
        <xsl:variable name="def_id" select="@xml:id"/>
        <xsl:variable name="def" select="normalize-space(.)"/>
        <xsl:variable name="sense_id" select="parent::*:sense/@xml:id"/>
        <xsl:variable name="sense_n" select="parent::*:sense/@n"/>
        <xsl:variable name="parent_sense_id" select="parent::*:sense/@parent-size"/>
        <xsl:variable name="parent_sense_collocs" select="if(preceding-sibling::*:colloc) then(string-join(preceding-sibling::*:colloc,';')) else ('')"/>
        <xsl:variable name="parent_sense_usg" select="if(preceding-sibling::*:usg, ';') then (string-join(preceding-sibling::*:usg, ';')) else ('')"/>
        <xsl:variable name="parent_sense_gram" select="if(preceding-sibling::*:gramGrp, ';') then (string-join(preceding-sibling::*:gramGrp, ';')) else ('')"/>
        <xsl:value-of select="$sense_n"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$sense_id"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$parent_sense_id"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$parent_sense_collocs"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$parent_sense_usg"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$parent_sense_gram"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$entry_id"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$def_id"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$def"/>
        <xsl:text>&#xA;</xsl:text>
    </xsl:template>    
<!--    <xsl:template match="*:def" mode="definitions">
        <xsl:variable name="entry_id" select="parent::*:entryFree/@xml:id"/>
        <xsl:variable name="def_id" select="@xml:id"/>
        <xsl:variable name="def" select="normalize-space(.)"/>
        <xsl:value-of select="$entry_id"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$def_id"/>
        <xsl:text>&#009;</xsl:text>
        <xsl:value-of select="$def"/>
        <xsl:text>&#xA;</xsl:text>
    </xsl:template>-->

    
</xsl:stylesheet>