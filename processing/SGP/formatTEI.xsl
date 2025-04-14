<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math" exclude-result-prefixes="xs math"
    version="3.0">
    <xsl:output method="xml" indent="yes"/>
    <xsl:mode on-no-match="shallow-copy"/>
    <xsl:mode name="group_usg_qual" on-no-match="shallow-copy"/>
    <xsl:mode name="group_usg_geo" on-no-match="shallow-copy"/>
    <xsl:mode name="find_sense_1" on-no-match="shallow-copy"/>
    <xsl:mode name="group_numbered" on-no-match="shallow-copy"/>
    <xsl:mode name="find_sense_2" on-no-match="shallow-copy"/>
    <xsl:mode name="find_sense_3" on-no-match="shallow-copy"/>
    <xsl:mode name="group_segs" on-no-match="shallow-copy"/>
    <xsl:mode name="group_cit" on-no-match="shallow-copy"/>
    <xsl:mode name="group_quote_cit" on-no-match="shallow-copy"/>
    <xsl:mode name="group_bibl" on-no-match="shallow-copy"/>
    <xsl:mode name="struct_xref" on-no-match="shallow-copy"/>
    <xsl:mode name="struct_num" on-no-match="shallow-copy"/>
    <xsl:mode name="add_ids" on-no-match="shallow-copy"/>

    <xsl:template match="/">
        <!-- Group neighbour usg qual -->
        <xsl:variable name="group_usg_qual">
            <xsl:apply-templates mode="group_usg_qual"/>
        </xsl:variable>

        <!-- Group neighbour placenames -->
        <xsl:variable name="group_usg_geo">
            <xsl:apply-templates mode="group_usg_geo" select="$group_usg_qual"/>
        </xsl:variable>

        <!-- Find numbered senses -->
        <xsl:variable name="find_sense_1">
            <xsl:apply-templates select="$group_usg_geo" mode="find_sense_1"/>
        </xsl:variable>

        <!-- Group numbered senses -->
        <xsl:variable name="group_numbered">
            <xsl:apply-templates select="$find_sense_1" mode="group_numbered"/>
        </xsl:variable>

        <!-- Definicje itp. w entryFree -->
        <xsl:variable name="find_sense_2">
            <xsl:apply-templates select="$group_numbered" mode="find_sense_2"/>
        </xsl:variable>
        
        <!-- Definicje itp. w sense -->
        <xsl:variable name="find_sense_3">
            <xsl:apply-templates select="$find_sense_2" mode="find_sense_3"/>
        </xsl:variable>

        <!-- Groups starting with lbl -->
        <xsl:variable name="group_segs">
            <xsl:apply-templates select="$find_sense_3" mode="group_segs"/>
        </xsl:variable>

        <xsl:variable name="group_bibl">
            <xsl:apply-templates select="$group_segs" mode="group_bibl"/>
        </xsl:variable>

        <!-- Free usg / bibl / pc groups -->
        <xsl:variable name="group_cit">
            <xsl:apply-templates select="$group_bibl" mode="group_cit"/>
        </xsl:variable>

        <!-- Group quotes without cit -->
        <xsl:variable name="group_quote_cit">
            <xsl:apply-templates select="$group_cit" mode="group_quote_cit"/>
        </xsl:variable>

        <!-- Structure xref entries -->
        <xsl:variable name="struct_xref">
            <xsl:apply-templates select="$group_quote_cit" mode="struct_xref"/>
        </xsl:variable>

        <!-- Structure numeric settlements -->
        <xsl:variable name="struct_num">
            <xsl:apply-templates select="$struct_xref" mode="struct_num"/>
        </xsl:variable>

        <xsl:variable name="add_ids">
            <xsl:apply-templates select="$struct_num" mode="add_ids"/>
        </xsl:variable>
        <xsl:copy-of select="$add_ids"/>
        <!--<xsl:copy-of select="$find_sense_1"/>-->
    </xsl:template>

    <!-- Some basic transformations -->
    <!--    <xsl:template match="*:ref[contains(.,'jw')][not(parent::*:bibl)]">
        <xsl:element name="bibl">
            <xsl:copy>
                <xsl:apply-templates/>
            </xsl:copy>
        </xsl:element>
    </xsl:template>-->
    <xsl:template mode="group_usg_qual" match="*:entryFree">
        <xsl:copy>
            <xsl:for-each-group select="*" group-adjacent="boolean(self::*:usg[@type = 'qual'])">
                <xsl:choose>
                    <xsl:when test="current-grouping-key()">
                        <xsl:choose>
                            <xsl:when test="count(current-group()) > 1">
                                <xsl:element name="usg">
                                    <xsl:attribute name="type" select="'qual'"/>
                                    <xsl:for-each select="current-group()">
                                        <xsl:copy>
                                            <xsl:copy-of select="@*"/>
                                            <xsl:apply-templates select="node()" mode="#current"/>
                                        </xsl:copy>
                                    </xsl:for-each>
                                </xsl:element>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:apply-templates select="current-group()" mode="#current"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:apply-templates select="current-group()" mode="#current"/>
                    </xsl:otherwise>
                </xsl:choose>

            </xsl:for-each-group>
        </xsl:copy>
    </xsl:template>

    <!-- Structure numeric settlements -->
    <xsl:template mode="struct_num"
        match="self::*:usg[@type = 'geo'][following-sibling::*[1][self::*:num]]">
        <xsl:copy>
            <xsl:apply-templates select="node() | @*" mode="#current"/>
            <xsl:element name="settlement">
                <xsl:element name="abbr">
                    <xsl:copy-of select="following-sibling::*[1][self::*:num]"/>
                </xsl:element>
            </xsl:element>
        </xsl:copy>
    </xsl:template>
    <!-- Remove dangling nums -->
    <xsl:template mode="struct_num"
        match="*:num[preceding-sibling::*[1][self::*:usg[@type = 'geo']]]"/>

    <!-- Repair xref entries -->
    <xsl:template mode="struct_xref"
        match="*:entryFree[@type = 'xref'][not(@n) or normalize-space(@n) eq '']">
        <xsl:copy>
            <xsl:apply-templates mode="#current" select="@*"/>
            <!--<xsl:attribute name="n" select="'aaaa'"/>-->
            <xsl:attribute name="n" select="normalize-space(*:form[1]/*:orth[1]/text())"/>
            <xsl:apply-templates mode="#current" select="node()"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template mode="struct_xref" match="*:form[@type = 'lemma']">
        <xsl:copy>
            <xsl:apply-templates mode="#current" select="node()"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template mode="struct_xref" match="*:orth[parent::*:form[@type = 'lemma']]">
        <xsl:copy>
            <xsl:attribute name="type" select="'lemma'"/>
            <xsl:apply-templates mode="#current" select="node()"/>
        </xsl:copy>
    </xsl:template>
    <xsl:template mode="struct_xref"
        match="*:xr[following-sibling::*[1][self::*:ref]] | *:xr[following-sibling::*[1][self::*:pc]][following-sibling::*[2][self::*:ref]]">
        <xsl:element name="xr">
            <xsl:element name="lbl">
                <xsl:value-of select="."/>
            </xsl:element>
            <xsl:if test="following-sibling::*[1][self::*:pc]">
                <xsl:copy-of select="following-sibling::*[1][self::*:pc]"/>
            </xsl:if>
            <xsl:call-template name="struct_ref">
                <xsl:with-param name="ref">
                    <xsl:if test="following-sibling::*[1][self::*:ref]">
                        <xsl:copy-of select="following-sibling::*[1][self::*:ref]"/>
                    </xsl:if>
                    <xsl:if test="following-sibling::*[1][self::*:pc]">
                        <xsl:copy-of select="following-sibling::*[2][self::*:ref]"/>
                    </xsl:if>
                </xsl:with-param>
            </xsl:call-template>
        </xsl:element>
    </xsl:template>
    <xsl:template name="struct_ref">
        <xsl:param name="ref"/>
        <xsl:element name="ref">
            <xsl:attribute name="type" select="'intra'"/>
            <xsl:attribute name="target" select="'#xpath'"/>
            <xsl:value-of select="$ref"/>
        </xsl:element>
    </xsl:template>
    <!-- remove dangling ref and pc -->
    <xsl:template mode="struct_xref"
        match="*:ref[preceding-sibling::*[1][self::*:xr]] | *:ref[preceding-sibling::*[1][self::*:pc]][preceding-sibling::*[2][self::*:xr]] | *:pc[preceding-sibling::*[1][self::*:xr]][following-sibling::*[1][self::*:ref]]"/>

    <xsl:template match="*:cit[preceding-sibling::*[1][self::*:quote]]" mode="group_quote_cit">
        <xsl:element name="cit">
            <xsl:apply-templates select="preceding-sibling::*[1][self::*:quote]"
                mode="include-in-cit"/>
            <xsl:apply-templates select="@* | node()" mode="group_quote_cit"/>
        </xsl:element>
    </xsl:template>

    <xsl:template match="*:cit[preceding-sibling::*[1][self::*:lbl[matches(., '~')]]]"
        mode="group_quote_cit">
        <xsl:element name="cit">
            <xsl:apply-templates select="preceding-sibling::*[1][self::*:lbl[matches(., '~')]]"
                mode="include-in-cit"/>
            <xsl:apply-templates select="@* | node()" mode="group_quote_cit"/>
        </xsl:element>
    </xsl:template>

    <xsl:template match="*:usg[@type = 'geo'][preceding-sibling::*[1][self::*:quote]]"
        mode="group_quote_cit">
        <xsl:element name="cit">
            <xsl:apply-templates select="preceding-sibling::*[1][self::quote]" mode="include-in-cit"/>
            <xsl:copy-of select="."/>
        </xsl:element>
    </xsl:template>

    <xsl:template match="*:quote | *:lbl" mode="include-in-cit">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()" mode="group_quote_cit"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template
        match="*:quote[following-sibling::*[1][self::*:cit]] | *:quote[following-sibling::*[1][self::*:usg[@type = 'geo']]]"
        mode="group_quote_cit"/>
    <xsl:template match="*:lbl[matches(., '~')][following-sibling::*[1][self::*:cit]]"
        mode="group_quote_cit"/>

    <xsl:template name="group_usg_geo">
        <xsl:param name="content"/>
        <!-- usg followed by usage of the same type containing [] -->
        <xsl:for-each-group select="$content"
            group-starting-with="*:usg[@type = 'geo'][following-sibling::*[1][self::*:usg[@type = 'geo'][matches(string-join(.//text()), '\[|\]')]]]">
            <xsl:choose>
                <xsl:when
                    test="current-group()[1][self::*:usg[@type = 'geo'][following-sibling::*[1][self::*:usg[@type = 'geo'][matches(string-join(.//text()), '\[|\]')]]]]">
                    <!-- copy first two elements of the group -->
                    <xsl:element name="usg">
                        <xsl:copy-of select="current-group()[1]/@*"/>
                        <xsl:attribute name="subtype" select="'zsrr'"/>
                        <xsl:copy-of select="current-group()[1]/node() | text()"/>
                        <xsl:copy-of select="current-group()[2]/node() | text()"/>
                    </xsl:element>
                    <xsl:call-template name="group_usg_geo">
                        <xsl:with-param name="content" select="current-group()[position() &gt; 2]"/>
                    </xsl:call-template>
                </xsl:when>
                <!-- incorrectly separated usg geo containing region or settlement -->
                <xsl:otherwise>
                    <xsl:for-each-group select="current-group()"
                        group-starting-with="*:usg[@type = 'geo'][descendant::*[self::*:settlement or self::*:region]][following-sibling::*[1][self::*:usg[@type = 'geo'][descendant::*[self::*:settlement or self::*:region]]]]">
                        <!--      <grupka>
                           <xsl:copy-of select="current-group()"></xsl:copy-of>
                       </grupka>-->
                        <xsl:choose>
                            <xsl:when
                                test="current-group()[1][self::*:usg[@type = 'geo'][descendant::*[self::*:settlement or self::*:region]][following-sibling::*[1][self::*:usg[@type = 'geo'][descendant::*[self::*:settlement or self::*:region]]]]]">
                                <!--<jestem_poprawny><xsl:copy-of select="current-group()[1]"></xsl:copy-of></jestem_poprawny>-->
                                <!-- copy first two elements of the group -->
                                <xsl:element name="usg">
                                    <xsl:copy-of select="current-group()[1]/@*"/>
                                    <xsl:copy-of select="current-group()[1]/node() | text()"/>
                                    <xsl:copy-of select="current-group()[2]/node() | text()"/>
                                </xsl:element>
                                <xsl:for-each select="current-group()[position() &gt; 2]">
                                    <xsl:copy>
                                        <xsl:copy-of select="@*"/>
                                        <xsl:call-template name="group_usg_geo">
                                            <xsl:with-param name="content"
                                                select="./node() | text()"/>
                                        </xsl:call-template>
                                    </xsl:copy>
                                </xsl:for-each>
                            </xsl:when>
                            <xsl:otherwise>
                                <!--<jestem_niepoprawny><xsl:copy-of
                                    select="current-group()[1]"></xsl:copy-of></jestem_niepoprawny>-->
                                <xsl:for-each select="current-group()">
                                    <xsl:copy>
                                        <xsl:copy-of select="@*"/>
                                        <xsl:call-template name="group_usg_geo">
                                            <xsl:with-param name="content"
                                                select="./node() | text()"/>
                                        </xsl:call-template>
                                    </xsl:copy>
                                </xsl:for-each>
                                <!--<xsl:apply-templates select="current-group()" mode="#current"/>-->
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each-group>
                </xsl:otherwise>
            </xsl:choose>

        </xsl:for-each-group>
    </xsl:template>

    <xsl:template match="*:entryFree" mode="group_usg_geo">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:call-template name="group_usg_geo">
                <xsl:with-param name="content" select="node() | text()"/>
            </xsl:call-template>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="*:entryFree | *:sense | *:def | *:colloc | *:form | *:orth | *:quote" mode="add_ids">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:attribute name="xml:id" select="local-name() || '_' || generate-id()"/>
            <xsl:apply-templates mode="#current"/>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="*:entryFree" mode="find_sense_1">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:call-template name="find_sense_numbered">
                <xsl:with-param name="content" select="node() | text()"/>
            </xsl:call-template>
        </xsl:copy>
    </xsl:template>

    <xsl:template name="find_sense_numbered">
        <xsl:param name="content"/>
        <!-- wyodrębnienie sensu: standardowe definicje -->
        <xsl:for-each-group select="$content"
            group-starting-with="*:num[following-sibling::*[1][self::*:pc[matches(., '\.')][following-sibling::*[1][self::*:def | self::*:gramGrp[following-sibling::*[1][self::*:def]] | self::*:usg[following-sibling::*[1][self::*:def]]]]]]">
            <xsl:choose>
                <xsl:when
                    test="current-group()[1][self::*:num[following-sibling::*[1][self::*:pc[matches(., '\.')][following-sibling::*[1][self::*:def | self::*:gramGrp[following-sibling::*[1][self::*:def]] | self::*:usg[following-sibling::*[1][self::*:def]]]]]]]">
                    <sense>
                        <xsl:attribute name="n" select="current-group()[1]"/>
                        <xsl:choose>
                            <xsl:when test="count(current-group()/*:def) &gt; 1">
                                <xsl:apply-templates select="current-group()[1]" mode="#current"/>
                                <xsl:call-template name="find_sense_numbered">
                                    <xsl:with-param name="content"
                                        select="current-group()[position() &gt; 1]"/>
                                </xsl:call-template>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:apply-templates select="current-group()" mode="#current"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </sense>
                </xsl:when>
                <xsl:otherwise>
                    <!--<grupka><xsl:copy-of select="current-group()"></xsl:copy-of></grupka>-->
                    <xsl:apply-templates select="current-group()" mode="#current"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each-group>
    </xsl:template>

    <xsl:template name="group_numbered">
        <xsl:param name="content"/>
        <xsl:for-each-group select="$content" group-starting-with="*:sense[matches(@n, 'I|V|X')]">
            <xsl:choose>
                <xsl:when test="current-group()[1][self::*:sense[matches(@n, 'I|V|X')]]">
                    <xsl:copy>
                        <xsl:copy-of select="@*"/>
                        <xsl:apply-templates mode="#current"
                            select="current-group()[1]/node() | text()"/>
                        <xsl:call-template name="group_numbered">
                            <xsl:with-param name="content"
                                select="current-group()[position() &gt; 1]"/>
                        </xsl:call-template>
                    </xsl:copy>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:for-each-group select="current-group()"
                        group-starting-with="*:sense[matches(@n, '\d+')]">
                        <xsl:choose>
                            <xsl:when test="current-group()[1][self::*:sense[matches(@n, '\d+')]]">
                                <xsl:copy>
                                    <xsl:copy-of select="@*"/>
                                    <xsl:apply-templates mode="#current"
                                        select="current-group()[1]/node() | text()"/>
                                    <xsl:call-template name="group_numbered">
                                        <xsl:with-param name="content"
                                            select="current-group()[position() &gt; 1]"/>
                                    </xsl:call-template>
                                </xsl:copy>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:for-each-group select="current-group()"
                                    group-starting-with="*:sense[matches(@n, '[a-z]')]">
                                    <xsl:choose>
                                        <xsl:when
                                            test="current-group()[1][self::*:sense[matches(@n, '[a-z]')]]">
                                            <xsl:copy>
                                                <xsl:copy-of select="@*"/>
                                                <xsl:apply-templates mode="#current"
                                                  select="current-group()[1]/node() | text()"/>
                                                <xsl:call-template name="group_numbered">
                                                  <xsl:with-param name="content"
                                                  select="current-group()[position() &gt; 1]"/>
                                                </xsl:call-template>
                                            </xsl:copy>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:for-each-group select="current-group()"
                                                group-starting-with="*:sense[matches(@n, '[α-ω]')]">
                                                <xsl:choose>
                                                  <xsl:when
                                                  test="current-group()[1][self::*:sense[matches(@n, '[α-ω]')]]">
                                                  <xsl:copy>
                                                  <xsl:copy-of select="@*"/>
                                                  <xsl:apply-templates mode="#current"
                                                  select="current-group()[1]/node() | text()"/>
                                                  <xsl:call-template name="group_numbered">
                                                  <xsl:with-param name="content"
                                                  select="current-group()[position() &gt; 1]"/>
                                                  </xsl:call-template>
                                                  </xsl:copy>
                                                  </xsl:when>
                                                  <xsl:otherwise>
                                                  <!--<xsl:apply-templates select="current-group()" mode="#current"/>-->
                                                  <xsl:apply-templates select="current-group()"
                                                  mode="#current"/>
                                                  </xsl:otherwise>
                                                </xsl:choose>
                                            </xsl:for-each-group>
                                            <!--<xsl:apply-templates select="current-group()" mode="#current"/>-->

                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:for-each-group>
                                <!--<xsl:apply-templates select="current-group()" mode="#current"/>-->
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each-group>
                    <!--<xsl:apply-templates select="current-group()" mode="#current"/>-->
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each-group>
    </xsl:template>

    <xsl:template match="*:entryFree" mode="group_numbered">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:call-template name="group_numbered">
                <xsl:with-param name="content" select="node() | text()"/>
            </xsl:call-template>
        </xsl:copy>
    </xsl:template>


    <xsl:template match="*:entryFree" mode="find_sense_2">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:call-template name="find_sense_notnumbered">
                <xsl:with-param name="content" select="node() | text()"/>
            </xsl:call-template>
        </xsl:copy>
    </xsl:template>

    <xsl:template match="*:sense[count(*:def) &gt; 1] | *:sense[*:colloc]" mode="find_sense_3">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <!--<pos><xsl:value-of select="*[self::*:def[1]]/position()"/></pos>-->
            <xsl:apply-templates mode="#current" select="*:def[1]/preceding-sibling::*"/>
            <xsl:apply-templates mode="#current" select="*:def[1]"/>
            <xsl:call-template name="find_sense_notnumbered">
                <xsl:with-param name="content" select="*:def[1]/following-sibling::*"/>
            </xsl:call-template>
        </xsl:copy>
    </xsl:template>


    <xsl:template name="find_sense_notnumbered">
        <xsl:param name="content"/>
        <!-- definicje z ~ i grupą gramGrp itd. -->
        <xsl:for-each-group select="$content"
            group-starting-with="*:lbl[matches(., '~|≈')][following-sibling::*[1][self::*:gramGrp or self::*:def or self::*:colloc or self::*:usg]]">
            <xsl:choose>
                <xsl:when
                    test="current-group()[1][self::*:lbl[matches(., '~|≈')][following-sibling::*[1][self::*:gramGrp or self::*:def or self::*:colloc or self::*:usg]]]">

                    <sense>
                        <xsl:attribute name="n" select="current-group()[1]"/>
                        <xsl:apply-templates select="current-group()[position() &lt;= 2]"/>
                        <xsl:call-template name="find_sense_notnumbered">
                            <xsl:with-param select="current-group()[position() &gt; 2]" name="content"/>
                        </xsl:call-template>
                    </sense>
                </xsl:when>
                <xsl:otherwise>
                    <!-- definicje: gramgrp + def (bez lbl)
                                    -->
                    <xsl:for-each-group select="current-group()"
                        group-starting-with="*[self::*:gramGrp or self::*:colloc or self::*:usg][following-sibling::*[1][self::*:def]]">
                        <xsl:choose>
                            <xsl:when
                                test="current-group()[1][self::*:gramGrp or self::*:colloc or self::*:usg][following-sibling::*[1][self::*:def]]">
                                   <sense>
                                    <xsl:attribute name="n" select="current-group()[1]"/>
                                    <xsl:apply-templates select="current-group()[position() &lt;= 2]"/>
                                    <xsl:call-template name="find_sense_notnumbered">
                                        <xsl:with-param select="current-group()[position() &gt; 2]" name="content"/>
                                    </xsl:call-template>
                                </sense>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:for-each-group select="current-group()"
                                    group-starting-with="*[self::*:def]">
                                    <xsl:choose>
                                        <xsl:when test="current-group()[1][self::*:def]">
                                            <xsl:variable name="position-of-def">
                                                <xsl:for-each select="current-group()">
                                                  <xsl:if test="self::*:def">
                                                  <xsl:value-of select="position()"/>
                                                  </xsl:if>
                                                </xsl:for-each>
                                            </xsl:variable>
                                            <sense>
                                                <!--<xsl:attribute name="n" select="current-group()[1]"/>-->
                                                <xsl:apply-templates
                                                    select="current-group()[position() &lt;= 1]"/>
                                                <xsl:call-template name="find_sense_notnumbered">
                                                    <xsl:with-param
                                                        select="current-group()[position() &gt; 1]" name="content"/>
                                                </xsl:call-template>
                                            </sense>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:for-each-group select="current-group()"
                                                group-starting-with="*[self::*:colloc]">
                                                <xsl:choose>
                                                    <xsl:when test="current-group()[1][self::*:colloc]">
                                                        <sense>
                                                            <xsl:attribute name="n" select="current-group()[1]"/>
                                                            <xsl:apply-templates
                                                                select="current-group()[position() &lt;= 1]"/>
                                                            <xsl:call-template name="find_sense_notnumbered">
                                                                <xsl:with-param
                                                                    select="current-group()[position() &gt; 1]" name="content"/>
                                                            </xsl:call-template>
                                                        </sense>
                                                    </xsl:when>
                                                    <xsl:otherwise>
                                                        <xsl:apply-templates select="current-group()"
                                                            mode="#current"/>
                                                        <!-- <xsl:for-each select="current-group()">
                                                <xsl:apply-templates select="."
                                                    mode="#current"/>    
                                            </xsl:for-each>-->
                                                    </xsl:otherwise>
                                                </xsl:choose>
                                            </xsl:for-each-group>
                                            
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:for-each-group>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each-group>
                </xsl:otherwise>
            </xsl:choose>

        </xsl:for-each-group>
        <!--  <content>
        <xsl:copy-of select="$content"></xsl:copy-of>
    </content>-->
    </xsl:template>

    <xsl:template match="*:entryFree" mode="group_segs">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:call-template name="group_segs">
                <xsl:with-param name="content" select="node() | text()"/>
            </xsl:call-template>
        </xsl:copy>
    </xsl:template>
    <xsl:template name="group_segs">
        <xsl:param name="content"/>
        <xsl:for-each-group select="$content"
            group-starting-with="*:lbl[matches(., 'Forma|Formy|Znaczenie|Znaczenia|Fraz|Frazeologia|W połączeniach|Przen')]">
            <xsl:choose>
                <xsl:when
                    test="current-group()[1][self::*:lbl[matches(., 'Forma|Formy|Znaczenie|Znaczenia|Fraz|Frazeologia|W połączeniach|Przen')]]">
                    <xsl:variable name="seg_type">
                        <xsl:if test="current-group()[1][self::*:lbl[matches(., 'Forma|Formy')]]">
                            <xsl:value-of select="'form'"/>
                        </xsl:if>
                        <xsl:if
                            test="current-group()[1][self::*:lbl[matches(., 'Znaczenie|Znaczenia')]]">
                            <xsl:value-of select="'sense'"/>
                        </xsl:if>
                        <xsl:if
                            test="current-group()[1][self::*:lbl[matches(., 'Fraz|Frazeologia|połączeniach')]]">
                            <xsl:value-of select="'phrase'"/>
                        </xsl:if>
                        <xsl:if test="current-group()[1][self::*:lbl[matches(., 'Przen')]]">
                            <xsl:value-of select="'metaph'"/>
                        </xsl:if>
                    </xsl:variable>
                    <xsl:element name="seg">
                        <xsl:attribute name="type" select="$seg_type"/>
                        <xsl:copy-of select="current-group()[1]"/>
                        <xsl:call-template name="group_segs">
                            <xsl:with-param name="content"
                                select="current-group()[position() &gt; 1]"/>
                        </xsl:call-template>
                    </xsl:element>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:for-each select="current-group()">
                        <xsl:copy>
                            <xsl:copy-of select="@*"/>
                            <xsl:call-template name="group_segs">
                                <xsl:with-param name="content" select="./node() | text()"/>
                            </xsl:call-template>
                        </xsl:copy>
                    </xsl:for-each>
                    <!--<xsl:apply-templates select="current-group()" mode="#current"/>-->
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each-group>
    </xsl:template>


    <xsl:template name="group_cit">
        <xsl:param name="content"/>
        <xsl:for-each-group select="$content"
            group-starting-with="*:usg[@type = ('qual', 'geo')][not(parent::*:cit)]">
            <xsl:choose>
                <xsl:when
                    test="current-group()[1][self::*:usg[@type = ('qual', 'geo')][not(parent::*:cit)]]">
                    <xsl:for-each-group select="current-group()"
                        group-ending-with="*[descendant-or-self::*:pc[matches(., '\.|;')]]">
                        <xsl:choose>
                            <xsl:when
                                test="current-group()[1][self::*:usg[@type = ('qual', 'geo')][not(parent::*:cit)]] and current-group()[last()][descendant-or-self::*:pc[matches(., '\.|;')]]">
                                <xsl:element name="cit">
                                    <xsl:apply-templates mode="#current" select="current-group()"/>
                                </xsl:element>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:for-each-group select="current-group()"
                                    group-starting-with="*:ref[preceding-sibling::*[1][self::*:quote or self::*:cit]]">
                                    <xsl:choose>
                                        <xsl:when
                                            test="current-group()[1][self::*:ref[preceding-sibling::*[1][self::*:quote or self::*:cit]]]">
                                            <xsl:for-each-group select="current-group()"
                                                group-ending-with="*[descendant-or-self::*:pc[matches(., '\.|;')]]">
                                                <xsl:choose>
                                                  <xsl:when
                                                  test="current-group()[1][self::*:ref[preceding-sibling::*[1][self::*:quote or self::*:cit]]] and current-group()[last()][descendant-or-self::*:pc[matches(., '\.|;')]]">
                                                  <xsl:element name="cit">
                                                  <xsl:apply-templates mode="#current"
                                                  select="current-group()"/>
                                                  </xsl:element>
                                                  </xsl:when>
                                                  <xsl:otherwise>
                                                  <xsl:for-each select="current-group()">
                                                  <xsl:copy>
                                                  <xsl:copy-of select="@*"/>
                                                  <xsl:call-template name="group_cit">
                                                  <xsl:with-param name="content"
                                                  select="./node() | text()"/>
                                                  </xsl:call-template>
                                                  </xsl:copy>
                                                  </xsl:for-each>
                                                  <!--<xsl:apply-templates select="current-group()" mode="#current"/>-->
                                                  </xsl:otherwise>
                                                </xsl:choose>
                                            </xsl:for-each-group>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:for-each select="current-group()">
                                                <xsl:copy>
                                                  <xsl:copy-of select="@*"/>
                                                  <xsl:call-template name="group_cit">
                                                  <xsl:with-param name="content"
                                                  select="./node() | text()"/>
                                                  </xsl:call-template>
                                                </xsl:copy>
                                            </xsl:for-each>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:for-each-group>
                                <!--<xsl:apply-templates select="current-group()" mode="#current"/>-->
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each-group>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:for-each select="current-group()">
                        <xsl:copy>
                            <xsl:copy-of select="@*"/>
                            <xsl:call-template name="group_cit">
                                <xsl:with-param name="content" select="./node() | text()"/>
                            </xsl:call-template>
                        </xsl:copy>
                    </xsl:for-each>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each-group>
    </xsl:template>

    <xsl:template match="*:entryFree" mode="group_cit">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:call-template name="group_cit">
                <xsl:with-param name="content" select="node() | text()"/>
            </xsl:call-template>
        </xsl:copy>
    </xsl:template>

    <xsl:template name="group_bibl">
        <xsl:param name="content"/>
        <xsl:for-each-group select="$content"
            group-starting-with="*:title[not(parent::*:bibl or parent::*:cit)]">
            <xsl:choose>
                <xsl:when
                    test="current-group()[1][self::*:title[not(parent::*:bibl or parent::*:cit)]]">
                    <xsl:for-each-group select="current-group()"
                        group-ending-with="*:pc[matches(., '\.|;')]">
                        <xsl:choose>
                            <xsl:when
                                test="current-group()[1][self::*:title[not(parent::*:bibl or parent::*:cit)]] and current-group()[last()][self::*:pc[matches(., '\.|;')]]">
                                <xsl:element name="bibl">
                                    <xsl:apply-templates mode="#current" select="current-group()"/>
                                </xsl:element>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:for-each select="current-group()">
                                    <xsl:copy>
                                        <xsl:copy-of select="@*"/>
                                        <xsl:call-template name="group_bibl">
                                            <xsl:with-param name="content"
                                                select="./node() | text()"/>
                                        </xsl:call-template>
                                    </xsl:copy>
                                </xsl:for-each>
                                <!--<xsl:apply-templates select="current-group()" mode="#current"/>-->
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:for-each-group>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:for-each select="current-group()">
                        <xsl:copy>
                            <xsl:copy-of select="@*"/>
                            <xsl:call-template name="group_bibl">
                                <xsl:with-param name="content" select="./node() | text()"/>
                            </xsl:call-template>
                        </xsl:copy>
                    </xsl:for-each>
                    <!--<xsl:apply-templates select="current-group()" mode="#current"/>-->
                </xsl:otherwise>
            </xsl:choose>
        </xsl:for-each-group>
    </xsl:template>

    <xsl:template match="*:entryFree" mode="group_bibl">
        <xsl:copy>
            <xsl:copy-of select="@*"/>
            <xsl:call-template name="group_bibl">
                <xsl:with-param name="content" select="node() | text()"/>
            </xsl:call-template>
        </xsl:copy>
    </xsl:template>


</xsl:stylesheet>