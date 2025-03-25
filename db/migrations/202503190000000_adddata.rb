require "sequel"

Sequel.migration do
  change do
    script_content = <<~CODE
      #!/bin/bash

      need_spec="n"
      SPEC="$1"
      FIND_SPEC="$SPEC"
      if [ -z "$SPEC" ];then
          need_spec="y"
      fi
      if [ -n "$SPEC" -a ! -e "$SPEC" ];then
          need_spec="y"
      fi
      if [ "$need_spec" == "y" ];then
          FIND_SPEC=$(/usr/bin/find . -iname "*.spec" -type f -print -quit)
      fi
      if [ -n "$FIND_SPEC" ];then
          NAME=$(rpm -q --queryformat="%{NAME}\n" --specfile "$FIND_SPEC" | xargs)
          VERSION=$(rpm -q --queryformat="%{VERSION}\n" --specfile "$FIND_SPEC" | xargs)
          PKG_NAME="${NAME}-${VERSION}"
          tar -h --exclude="${PKG_NAME}.tar.gz" --exclude=".git" --exclude="$FIND_SPEC" -cvf ${PKG_NAME}.tar.gz --transform "s,^,${PKG_NAME}/," *
          exit 0
      else
          echo "Не найден spec файл"
          exit 255
      fi
    CODE

    description = <<~CODE
      Скрипт для создания архива из исходников в гите, на основании spec файла.
      В репозитории должен быть один файл spec. Остальные будут игнорироваться.
    CODE

    from(:recips).insert(content: script_content, filepath: "make_tar_from_git", descr: description)
  end
end
