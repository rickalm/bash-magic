target=bash_magic.sh

rm ${target} &>/dev/null
touch ${target} &>/dev/null

for module in $(ls functions/*.sh ); do
  echo "" >>${target}
  echo "# Module ${module}" >>${target}
  echo "#" >>${target}
  echo "" >>${target}
  cat ${module} >>${target}
done
