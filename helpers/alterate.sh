#! /bin/bash
#
# Perform alteration on digits

# definitions
checkhelp(){
  echo "./alterate.sh enumerated-list.txt"
  exit 0
}

if [ $# -eq 0 ]; then
  checkhelp "$@"
fi


#######################################
# grep one digit to alterate
# Arguments:
#   file
# Example:
#   test.1.demo.com -->
#   test.2.demo.com
#   test.3.demo.com
#   ...
#######################################
onedigit(){
  ONEDIGIT=$(grep -E "[-][[:digit:]][-]" $1)
  if [[ $ONEDIGIT ]]; then
    for X in {0..102}; do
      echo "$ONEDIGIT" | sed "s/[-][[:digit:]][-]/-${X}-/"
    done
  fi

  ONEDIGIT_2=$(grep -E "[.][[:digit:]][.]" $1)
  if [[ $ONEDIGIT_2 ]]; then
    for X in {0..102}; do
      echo "$ONEDIGIT_2" | sed "s/[.][[:digit:]][.]/.${X}./"
    done
  fi

  ONEDIGIT_3=$(grep -E "[.][[:digit:]][-]" $1)
  if [[ $ONEDIGIT_3 ]]; then
    for X in {0..102}; do
      echo "$ONEDIGIT_3" | sed "s/[.][[:digit:]][-]/.${X}-/"
    done
  fi

  ONEDIGIT_4=$(grep -E "[-][[:digit:]][.]" $1)
  if [[ $ONEDIGIT_4 ]]; then
    for X in {0..102}; do
      echo "$ONEDIGIT_4" | sed "s/[-][[:digit:]][.]/-${X}./"
    done
  fi
}

#######################################
# grep two digits to alterate
# Arguments:
#   file
# Example:
#   test.28.demo.com -->
#   test.1.demo.com
#   ...
#   test.102.demo.com
#######################################
twodigit() {
  TWODIGIT_1=$(grep -E "[-][[:digit:]]{2}[-]" $1)
  if [[ $TWODIGIT_1 ]]; then
    for X in {0..102}; do
      echo "$TWODIGIT_1" | sed -E "s/[-][[:digit:]]{2}[-]/-${X}-/"
    done
  fi

  TWODIGIT_2=$(grep -E "[.][[:digit:]]{2}[.]" $1)
  if [[ $TWODIGIT_2 ]]; then
    for X in {0..102}; do
      echo "$TWODIGIT_2" | sed -E "s/[.][[:digit:]]{2}[.]/.${X}./"
    done
  fi
}

# main entry point
onedigit "$1"
twodigit "$1"
