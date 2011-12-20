#!/bin/bash

# ISABELLE_BIN_PATH (if isabelle is not located in PATH)

SCRIPT=$(readlink -f $0)
SCRIPTPATH=`dirname $SCRIPT`

if [ -z $1 ]; then
 echo "Nothing to translate!"
 exit 1
fi

TRANS=$(readlink -f $1)
TRANS_T=$(basename $TRANS .thy)
TRANS=$(dirname $TRANS)/$TRANS_T

if [ ! -r $TRANS.thy ]; then
 echo "Cannot read file $TRANS.thy"
 exit 1
fi

if [ ! -z $ISABELLE_BIN_PATH ]; then
 ISABELLE="$ISABELLE_BIN_PATH/isabelle"
 if [ ! -e $ISABELLE ]; then
  echo "Cannot find isabelle executable. Maybe you didn't specify ISABELLE_BIN_PATH correctly?"
 fi
else
 ISABELLE=`which isabelle`
 if [ $? ]; then
  echo "Cannot find isabelle executable. Maybe you need to specify ISABELLE_BIN_PATH"
  exit 1
 fi
fi

if [ ! -x $ISABELLE ]; then
 echo "$ISABELLE is not executable"
 exit 1
fi

echo $ISABELLE

(
 echo "theory IsaExport"
 echo "imports \"$TRANS\" Wellfounded"
 echo "uses \"$SCRIPTPATH/export_helper.ml\""
 echo "begin"
 echo "ML {*"
 echo "val T = Thy_Info.get_theory \"$TRANS_T\";
val name = Context.theory_name T;
val types = ExportHelper.get_datatypes T;
val consts = ExportHelper.filter (ExportHelper.get_gen_consts T name types)
                                 (ExportHelper.get_consts T);
val axioms = ExportHelper.filter (ExportHelper.get_gen_axioms T name types)
                                 (ExportHelper.get_axioms T);
val ths = ExportHelper.get_theorems T;
val theorems = ExportHelper.filter (ExportHelper.get_gen_theorems T name types (List.map #1 ths))
                                   ths;
val num_consts = List.length consts;
val num_axioms = List.length axioms;
val num_theorems = List.length theorems;
"
 echo "*}"
 echo "end;"

 #echo "ThyToOMDoc.ParseTheory \"$TRANS\";"
) | ($ISABELLE tty -p "")
