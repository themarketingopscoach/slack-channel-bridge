#!/bin/zsh
# Read-only status check for the OneSignal $150 incentive MQL setup, run by the Slack bot (roles/onesignal150-abi.md).
# Marketo: campaign config + people (GETs only). Salesforce: conversion, owner and sequence via sfq (read-only).
DIR="$HOME/Desktop/Temp Claude/OneSignal/Incentive 150 Sequencing/bot"
python3 -I "$DIR/verify_150.py" || echo "Marketo check failed (exit $?)"
echo
echo "Salesforce (contacts; this is where conversion and the Outreach sequence show first):"
python3 "$HOME/.claude/skills/sfdc-query/scripts/sfq.py" query onesignal --soql "SELECT Email, Contact_Status__c, Owner.Name, MQL__c, MQL_Date_Time__c, MR_MKTO_Interaction_at_MQL__c, Outreach_Sequence__c FROM Contact WHERE Email IN ('fkhushnood@kayak.com','mbrennan@thnks.com','abdeljalil.karam@tomtom.com','yyu@seek.com.au','jen.saper@hatch.co')" 2>&1 | tail -n +1
echo
ASANA_TOKEN="$(security find-generic-password -a "$USER" -s asana-onesignal-pat -w 2>/dev/null)" python3 -I "$DIR/asana_comments.py" || echo "Asana check failed"
