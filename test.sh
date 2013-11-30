#!/bin/bash

drupal_dest=/var/www/html/testing

function final_steps {
  cd ${drupal_dest}
  $(find . -type f -exec chmod u=rw,g=r,o=r '{}' \;);
  $(find . -type d -exec chmod u=rwx,g=rx,o=rx '{}' \;)
}


final_steps