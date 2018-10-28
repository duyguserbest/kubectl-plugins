#!/usr/bin/env bash

[[ -n $DEBUG ]] && set -x

set -eou pipefail
IFS=$'\n\t'

SELF_CMD="$0"

DEBUG=false



ACTION_P1="";
ACTION_P2="";
ACTION_P3="";
CMD="";
GET_CMD="";
CH_CMD="";
RESOURCE_TYPE="";
CMD_INDEX=0;

 loginfo(){
   if [[ $DEBUG == true ]]; then
    echo $1;
    fi
 }

usage() {

if [ -n "$1" ] ; then
    echo $1;
fi
 cat <<"EOF"

USAGE:
    kubectl bulk <resourceType>[<parameters>] get|list|create|update|delete|rollout  [<parameters>]
EOF

}

get() {

echo "$CH_CMD fields are getting";
eval "kubectl get ${GET_CMD} -o yaml > temp.yaml ";
CMD_DETAIL="";
INDEX=$((CMD_INDEX+1));
while [ "$INDEX" -le "$#" ]; do
CMD_DETAIL="$CMD_DETAIL -e ${@:$INDEX:1}:";
let INDEX=INDEX+1;
done;
LINES=( $(eval "grep -n -e name: $CMD_DETAIL temp.yaml | grep -Eo '^[^:]+'"));
COUNT=${#LINES[@]}
INDEX=0
while [ "$INDEX" -lt "$COUNT" ]; do
 eval "sed '${LINES[$INDEX]}!d' temp.yaml"  ;
    let INDEX=INDEX+1;
done
eval "rm temp.yaml";
}

list() {
 CMD_DETAIL="-o yaml";
 FORMAT="yaml";
 FILENAME="";

 if [[ "$ACTION_P2" != "" ]];then
     if [[ "$ACTION_P2" == "yaml" || "$ACTION_P2" == "json" ]];then
        FORMAT="$ACTION_P2";
        else
        FILENAME="$ACTION_P2";
     fi
 fi
 if [[ "$ACTION_P1" != "" ]];then
     if [[ "$ACTION_P1" == "yaml" || "$ACTION_P1" == "json" ]];then
        FORMAT="$ACTION_P1";
        else
        FILENAME=$ACTION_P1;
     fi
 fi

 if [[ "$FILENAME" != "" ]];then
    CMD_DETAIL="-o ${FORMAT} > ${FILENAME}.${FORMAT}";
    echo "All definitions will be written in ${FILENAME}.${FORMAT}";
else
    CMD_DETAIL="-o ${FORMAT}";
 fi

 loginfo "kubectl get ${GET_CMD} ${CMD_DETAIL}";
 eval "kubectl get ${GET_CMD} ${CMD_DETAIL}";
}

create() {

       loginfo "kubectl get ${GET_CMD} -o yaml | sed 's/$ACTION_P1: $ACTION_P2/$ACTION_P1: $ACTION_P3/' | kubectl create -f - ";
  if [[ $ACTION_P3 == "" ]];then
  echo "creating new resource with removing $ACTION_P1: line and added to $ACTION_P1: $ACTION_P2 for all $GET_CMD";
    case "$RESOURCE_TYPE" in  "svc"|"service")
            echo "!!!WARNING!!! CLUSTERIP and NODEPORT fields are REMOVED while creating new one";
            eval "kubectl get ${GET_CMD} -o yaml | sed 's/$ACTION_P1:/BULKPLUGINTEMPVAR\n $ACTION_P1:/' | sed '/$ACTION_P1:/d' |sed 's/BULKPLUGINTEMPVAR/$ACTION_P1: $ACTION_P2/' | sed '/clusterIP:/d' |  sed '/nodePort:/d' | kubectl create -f - ";
        ;;
        *)
            eval "kubectl get ${GET_CMD} -o yaml | sed 's/$ACTION_P1:/BULKPLUGINTEMPVAR\n $ACTION_P1:/' | sed '/$ACTION_P1:/d' |sed 's/BULKPLUGINTEMPVAR/$ACTION_P1: $ACTION_P2/' | kubectl create -f - ";
    esac
  else
  echo "creating new resource with changing $ACTION_P1: $ACTION_P2 to $ACTION_P1: $ACTION_P3 for all $GET_CMD";
    case "$RESOURCE_TYPE" in  "svc"|"service")
            echo "!!!WARNING!!! CLUSTERIP and NODEPORT fields are REMOVED while creating new one";
            eval "kubectl get ${GET_CMD} -o yaml | sed 's/$ACTION_P1: $ACTION_P2/$ACTION_P1: $ACTION_P3/' | sed '/clusterIP:/d' |  sed '/nodePort:/d' | kubectl create -f - ";
        ;;
        *)
            eval "kubectl get ${GET_CMD} -o yaml | sed 's/$ACTION_P1: $ACTION_P2/$ACTION_P1: $ACTION_P3/' | kubectl create -f - ";
    esac
  fi

}

update() {
  if [[ $ACTION_P3 == "" ]];then
    echo "updating resource with removing $ACTION_P1: line  and added $ACTION_P1: $ACTION_P2 for all $GET_CMD";
    loginfo "kubectl get ${GET_CMD} -o yaml | sed 's/$ACTION_P1: $ACTION_P2/$ACTION_P1: $ACTION_P3/' | kubectl replace -f - ";
    eval "kubectl get ${GET_CMD} -o yaml | sed 's/$ACTION_P1:/BULKPLUGINTEMPVAR\n $ACTION_P1:/' | sed '/$ACTION_P1:/d' |sed 's/BULKPLUGINTEMPVAR/$ACTION_P1: $ACTION_P2/' | kubectl replace -f - ";
  else
    echo "updating resource with changing $ACTION_P1: $ACTION_P2 to $ACTION_P1: $ACTION_P3 for all $GET_CMD";
    loginfo "kubectl get ${GET_CMD} -o yaml | sed 's/$ACTION_P1: $ACTION_P2/$ACTION_P1: $ACTION_P3/' | kubectl replace -f - ";
    eval "kubectl get ${GET_CMD} -o yaml | sed 's/$ACTION_P1: $ACTION_P2/$ACTION_P1: $ACTION_P3/' | kubectl replace -f - ";
  fi

}


rollout() {
echo "$RESOURCE_TYPEs are being rollout $CH_CMD"
loginfo "kubectl get ${GET_CMD} -o jsonpath={.items[*].metadata.name}| xargs kubectl rollout ${CH_CMD} ${GET_CMD} ";
eval "kubectl get ${GET_CMD} -o jsonpath={.items[*].metadata.name}| xargs kubectl rollout ${CH_CMD} ${GET_CMD} ";

}

delete() {
CMD_DETAIL="";
 if [[ "$ACTION_P2" != "" ]];then
     CMD_DETAIL="$ACTION_P2";
 elif [[ "$ACTION_P1" != "" ]];then
     CMD_DETAIL=""$ACTION_P1": ${CMD_DETAIL}";
 fi
 case "$CMD_DETAIL"  in ": " | "")
    loginfo "kubectl get ${GET_CMD} -o jsonpath={.items[*].metadata.name} |  xargs kubectl delete ${GET_CMD} ";
    eval "kubectl get ${GET_CMD} -o jsonpath={.items[*].metadata.name} | xargs kubectl delete ${GET_CMD} ";;
  *)
    loginfo "kubectl get ${GET_CMD} -o yaml | sed '/$CMD_DETAIL/d' | kubectl replace -f - ";
    eval "kubectl get ${GET_CMD} -o yaml | sed '/$CMD_DETAIL/d' | kubectl replace -f - ";
 esac
}

action_call() {

 if [[ $CMD  ==  "create" ]];then
      create;
    elif [[ $CMD == "update" ]];then
     update;
    elif [[ $CMD == "get" ]];then
      get "$@";
    elif [[ $CMD == "list" ]];then
      list;
    elif [[ $CMD == "delete" ]];then
      delete;
    elif [[ $CMD == "rollout" ]];then
      rollout;
    fi
}

read_parameters() {

if [[ "$#" -lt 1 ]]; then
        usage "";
        exit 0
fi

 COUNTER=1
 IS_GET=true
 RESOURCE_TYPE="$1"
         while [ $COUNTER -le "$#" ]; do
           loginfo "${@:$COUNTER:1}";

            case "${@:$COUNTER:1}" in  "get"|"list"|"create"|"update"|"delete"|"rollout")
                  CMD=${@:$COUNTER:1};
                  CMD_INDEX=$COUNTER;
                 IS_GET=false;
                 let COUNTER=COUNTER+1;
            esac

            loginfo $IS_GET;
             if [ $IS_GET == true ];then
                GET_CMD="$GET_CMD ${@:$COUNTER:1}"
              elif [ $IS_GET == false ];then
                CH_CMD="$CH_CMD ${@:$COUNTER:1}"
             fi
                    let COUNTER=COUNTER+1
             done
             loginfo "$GET_CMD";
             loginfo "$CH_CMD";
             loginfo $GET_CMD ;
             loginfo $CMD_INDEX;
   if [[ $CMD == "" ]];then
      list;
   fi

       ACTION_P1=${@:$((CMD_INDEX+1)):1};
       ACTION_P2=${@:$((CMD_INDEX+2)):1};
       ACTION_P3=${@:$((CMD_INDEX+3)):1};
       loginfo $ACTION_P1;
       loginfo $ACTION_P2;
       loginfo $ACTION_P3;

}
main() {

    read_parameters "$@";
    action_call "$@";

}



main "$@"