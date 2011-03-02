<?php
function smarty_function_mtdownloadscript ( $args, &$ctx ) {
    $downloadscript = $ctx->mt->config( 'DownloadScript' );
    if ( ! $downloadscript ) {
        $downloadscript = 'mt-download.cgi';
    }
    return $downloadscript;
}
?>