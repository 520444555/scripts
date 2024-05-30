gsutil cat gs://hsbc-10505826-inmdsw-prod-mainscripts-prod-01/dsw-init-jupyter-portal.sh
#!/bin/bash
set -exo pipefail
# this script only impacts master node
# 1. disable download upload
# 2. create ipython magic line command
# 3. point gcs bucket
readonly PROXY_IP=$(/usr/share/google/get_metadata_value attributes/PROXY_IP || true)
readonly PRI_FOLDER=$(/usr/share/google/get_metadata_value attributes/STAFF_ID)
readonly ATTACHED_BUCKET=$(/usr/share/google/get_metadata_value attributes/dataproc-bucket)
readonly DATAPROC_M=$(/usr/share/google/get_metadata_value attributes/dataproc-master)
readonly IMAGE_NAME=$(/usr/share/google/get_metadata_value image)
readonly PROD_GIT_ACCOUNT=$(/usr/share/google/get_metadata_value attributes/GIT_ACCOUNT)
readonly PROD_GIT_TOKEN=$(/usr/share/google/get_metadata_value attributes/GIT_TOKEN)
readonly ENV_TYPE=$(/usr/share/google/get_metadata_value attributes/ENV_TYPE)
readonly NEXUS_TOKEN_NAME=$(/usr/share/google/get_metadata_value attributes/NEXUS_TOKEN_NAME)
readonly NEXUS_TOKEN_PASSCODE=$(/usr/share/google/get_metadata_value attributes/NEXUS_TOKEN_PASSCODE)
readonly MAINSCRIPT_BUCKET=$(/usr/share/google/get_metadata_value attributes/MAINSCRIPT_BUCKET)
if [ -z "${PROXY_IP}" ]; then
    echo "ERROR: Must specify PROXY_IP metadata key"
    exit 1
elif [ -z "${PRI_FOLDER}" ]; then
    echo "ERROR: Must specify STAFF_ID as your personal folder"
    exit 1
fi
if [ "${DATAPROC_M}" != `hostname` ]; then
    echo "Worker node does not need Jupyter init. Will exit now."
    exit 0
fi
# !!! DO NOT modify those kernel.json files, you'll never know what will happen
#export python3_kernel_config=/opt/conda/anaconda/share/jupyter/kernels/python3/kernel.json
#export pyspark_kernel_config=/opt/conda/anaconda/share/jupyter/kernels/pyspark/kernel.json
export httpprox=http://${PROXY_IP}:3128
export httpsprox=https://${PROXY_IP}:3128
export jupyter_config_file_path=/etc/jupyter/jupyter_notebook_config.py
export jupyter_notebook_working_dir=/opt/jupyter/notebook/
export ipython_init_env_path=/root/.ipython/profile_default/startup/00-set-env.py
export ipython_register_magics_path=/root/.ipython/profile_default/startup/01-register-magics.py
export git_config=/root/.gitconfig
export git_credential=/root/.git-credentials
export git_account=GB-SVC-iHUBHK-GH
export git_token=28f063d7685615db445a76a84be8ccae3711ceff
export jupyter_contents_handler=/opt/conda/default/lib/python3.8/site-packages/notebook/services/contents/handlers.py
#/opt/conda/miniconda3/lib/python3.8/site-packages/notebook/services/contents/handlers.py
export file_init_success=/root/file_pull.succeeded
export ipython_alias_config_root=/root/.ipython/profile_default/ipython_config.py
export miniconda_config=/opt/conda/miniconda3/.condarc
export nexus_host=efx-nexus.systems.uk.hsbc:8084
export nexus_index_url=https://efx-nexus.systems.uk.hsbc:8084/nexus/repository/pypi/simple
export nexus_token_name=${NEXUS_TOKEN_NAME}
export nexus_token_code=${NEXUS_TOKEN_PASSCODE}
export mainscript_bucket=${MAINSCRIPT_BUCKET}
if [ "${ENV_TYPE}" == "PROD" ]; then
    export nexus_host=nexus302.systems.uk.hsbc:8081
    export nexus_index_url=https://${nexus_token_name}:${nexus_token_code}@nexus302.systems.uk.hsbc:8081/nexus/repository/pypi-hosted-iHub-dev-n3p/simple
    export git_account=${PROD_GIT_ACCOUNT}
    export git_token=${PROD_GIT_TOKEN}
fi
 
mkdir -p ${jupyter_notebook_working_dir}
gsutil -m rsync -r "gs://${ATTACHED_BUCKET}/${PRI_FOLDER}/notebooks/jupyter/"  ${jupyter_notebook_working_dir} ; rc=$?
 
if [ ${rc} -eq 0 ]; then
    touch ${file_init_success}
fi
echo "Invalid dataproc image. Please check image input again."
    exit 1
elif [ ${release_date_yyyymmdd} \> "20190822" ]; then
    sed -i '/c.NotebookApp.contents_manager_class = GCSContentsManager/d' ${jupyter_config_file_path}
    sed -i 's/c.GCSContentsManager.bucket_name/#c.GCSContentsManager.bucket_name/g' ${jupyter_config_file_path}
    sed -i 's/c.GCSContentsManager.bucket_notebooks_path/#c.GCSContentsManager.bucket_notebooks_path/g' ${jupyter_config_file_path}
    echo "c.NotebookApp.notebook_dir = '${jupyter_notebook_working_dir}'" >> ${jupyter_config_file_path}
    echo "c.ContentsManager.allow_hidden = True" >> ${jupyter_config_file_path}
    echo "c.NotebookApp.contents_manager_class = 'notebook.services.contents.largefilemanager.LargeFileManager'" >> ${jupyter_config_file_path}
    echo "c.MultiKernelManager.default_kernel_name = 'python3.7'" >> ${jupyter_config_file_path}
else
    sed -i 's/jgscm.GoogleStorageContentManager/notebook.services.contents.largefilemanager.LargeFileManager/g' ${jupyter_config_file_path}
    sed -i 's/c.GoogleStorageContentManager.default_path/#c.GoogleStorageContentManager.default_path/g' ${jupyter_config_file_path}
    echo "c.NotebookApp.notebook_dir = '${jupyter_notebook_working_dir}'" >> ${jupyter_config_file_path}
    echo "c.ContentsManager.allow_hidden = True" >> ${jupyter_config_file_path}
    echo "c.MultiKernelManager.default_kernel_name = 'python3.7'" >> ${jupyter_config_file_path}
fi
cat >> ${jupyter_config_file_path} << EOM
cat >> ${jupyter_config_file_path} << EOM
 
import os
 
def post_save_sync(model, os_path, contents_manager, **kwargs):
    """
        upload working dir to dataproc attached bucket
    """
    log = contents_manager.log
    command = "nohup ls ${file_init_success} && gsutil -m rsync -d -r ${jupyter_notebook_working_dir} gs://${ATTACHED_BUCKET}/${PRI_FOLDER}/notebooks/jupyter/  >> /var/log/rsync.logs 2>&1 &"
    os.system(command)
    log.info(command)
c.FileContentsManager.post_save_hook=post_save_sync
EOM
cat > ${git_config}<< EOM
[http]
        sslVerify = false
        proxy = "${httpprox}"
[credential]
        helper = store
[user]
        name = "${git_account}"-"${PRI_FOLDER}"
        email = "${git_account}"@NotReceivingMail.hsbc.com
EOM
cat > ${git_credential}<< EOM
https://${git_account}:${git_token}@alm-github.systems.uk.hsbc
EOM
ipython profile create
echo "c.AliasManager.user_aliases=[('git','git')]" >> ${ipython_alias_config_root}
 
cat > ${ipython_init_env_path}<< EOM
import os
os.environ['HOME'] = '/root/'
os.environ['PATH'] += os.pathsep + '/opt/conda/default/bin'
os.environ['httpprox'] = "${httpprox}"
os.environ['httpsprox'] = "${httpsprox}"
os.environ['nexus_host'] = "${nexus_host}"
os.environ['nexus_index_url'] = "${nexus_index_url}"
os.environ['nexus_user'] = "${nexus_user}"
os.environ['nexus_password'] = "${nexus_password}"
EOM
cat > ${ipython_register_magics_path} << EOM
# This code can be put in any Python module, it does not require IPython
# itself to be running already.  It only creates the magics subclass but
# doesn't instantiate it yet.
from __future__ import print_function
import os
import re
import sys
from IPython.core.magic import Magics, magics_class, line_magic
import subprocess
from IPython import get_ipython
 
# The class MUST call this class decorator at creation time
@magics_class
class IhubHelperTool(Magics):
    @line_magic
    def pip(self, line):
        """
        This is our self-defined magic for pip integration in GCP Jupyter.
        in order to wrap up HSBC-related configuration in command so that user need no extra input.
        usage is very similar to original pypi pip command
        if this class/module is properly registered.
        this magic can be called in Jupyter Cell like:
        %pip install google-cloud-bigquery==1.11.2 google-cloud-storage==1.15.0
or without % is also OK:
        pip uninstall google-cloud-bigquery
        the result CANNOT be grepped.
        :param line: string,
            this is the required param to do @line_magic
            eg: %pip install google-cloud-bigquery
            then line = "install google-cloud-bigquery"
        :return: no return. since we are using Ipython, either stdout or stderr will be printed and shown.
        """
        o, e, rc = self.pip_core(line)
        print(o)
        if rc == 0:
            print("DONE.")
        else:
            print(e)
def pip_core(self, line):
        """
        pip core logic.
        :param line: string,
            Parameters of pip command all in one string.
        :return:
        output: standard output of pip command execution
        error: error output of pip command execution
        return_code: return code of pip command execution
        """
        cmd = ['/opt/conda/default/bin/pip']
        if line != "":
            line_arr = re.findall(r'\".*\"|[-]{0,2}\S+|\.{1,2}', line)
            http_proxy = os.environ['httpprox']
            nexus_host = os.environ['nexus_host']
            nexus_index_url = os.environ['nexus_index_url']
            cmd.extend(line_arr)
            if "install" in line_arr:
                cmd.extend(['--proxy', http_proxy,
                            '--index-url', nexus_index_url,
                            '--trusted-host', nexus_host])
            elif "uninstall" in line_arr:
                cmd.append('--yes')
proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        output, error = proc.communicate()
        return output, error, proc.returncode
    @line_magic
    def pip_with_returncode(self, line):
        """
        pip command with return code and info shown.
        for testing purpose.
        :param line: string,
            Parameters of pip command all in one string.
        :return:
        return_code: return code of pip command execution
        stdout and stderr will be printed in Jupyter cell while execution.
        """
        o, e, rc = self.pip_core(line)
        print(o)
        print(e)
        return rc
    @line_magic
    def wget(self, line):
"""
        This is our self-defined magic for wget integration in GCP Jupyter.
        in order to wrap up HSBC-related configuration in command so that user need no extra input.
        usage is very similar to original pypi pip command
        if this class/module is properly registered.
        this magic can be called in Jupyter Cell like:
        %wget https://efx-nexus.systems.uk.hsbc:8084/nexus/repository/pypi/packages/aiohttp/3.6.2/aiohttp-3.6.2.tar.gz
        or
        wget https://efx-nexus.systems.uk.hsbc:8084/nexus/repository/pypi/packages/aiohttp/3.6.2/aiohttp-3.6.2.tar.gz
        :param line: string,
            this is the required param to do @line_magic
            eg: %pip install google-cloud-bigquery
            then line = "install google-cloud-bigquery"
        :return: no return. since we are using Ipython, either stdout or stderr will be printed and shown.
        """
o, e, rc = self.wget_core(line)
        print(o)
        if rc == 0:
            print("DONE.")
        else:
            print(e)
    def wget_core(self, line):
        """
        pip core logic.
        :param line: string,
            Parameters of pip command all in one string.
        :return:
        output: standard output of pip command execution
        error: error output of pip command execution
        return_code: return code of pip command execution
        """
        cmd = ['/usr/bin/wget']
        if line != "":
            line_arr = re.findall(r'\".*\"|[-]{0,2}\S+|\.{1,2}', line)
            http_proxy = os.environ['httpprox']
user = os.environ['nexus_user']
            password = os.environ['nexus_password']
            cmd.extend(line_arr)
            cmd.extend(['--no-check-certificate',
                        '--user={}'.format(user),
                        '--password={}'.format(password),
                        '-e', 'use_proxy=on',
                        '-e', 'https_proxy={}'.format(http_proxy)
                        ])
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
        output, error = proc.communicate()
        return output, error, proc.returncode
# In order to actually use these magics, you must register them with a
# running IPython.
ipython = get_ipython()
ipython.register_magics(IhubHelperTool)
EOM
 
cat >> ${jupyter_config_file_path} << EOM
from notebook.base.handlers import AuthenticatedFileHandler
from tornado import web
class MyFileHandler(AuthenticatedFileHandler):
    def get(self, path):
        raise web.HTTPError(403, log_message='You are not allowed to download {} from this page.'.format(path),
                            reason='forbidden')
 
 
c.ContentsManager.files_handler_class = MyFileHandler
EOM
sed -i 's/c.FileContentsManager.root_dir/#c.FileContentsManager.root_dir/g' ${jupyter_config_file_path}
sed -i 's/yield maybe_future(self._upload(model, path))/raise web.HTTPError(403, \"Cannot Upload\")/g' ${jupyter_contents_handler}
#sed -i 's/yield maybe_future(self._save(model, path))/raise web.HTTPError(403, \"Cannot Upload\")/g' ${jupyter_contents_handler}
cat > ${miniconda_config}  << EOM
always_yes: true
repodata_fns:
  - repodata.json
auto_update_conda: false
ssl_verify: False
channel_alias: https://${nexus_token_name}:${nexus_token_code}@nexus302.systems.uk.hsbc:8081/nexus/repository
changeps1: false
channels:
  - defaults
default_channels:
  - https://${nexus_token_name}:${nexus_token_code}@nexus302.systems.uk.hsbc:8081/nexus/repository/anaconda-main-proxy-n3p
  - https://${nexus_token_name}:${nexus_token_code}@nexus302.systems.uk.hsbc:8081/nexus/repository/anaconda-forge-proxy-n3p
channel_priority: strict
custom_channels:
  anaconda-main-proxy-n3p: https://${nexus_token_name}:${nexus_token_code}@nexus302.systems.uk.hsbc:8081/nexus/repository
  anaconda-forge-proxy-n3p: https://${nexus_token_name}:${nexus_token_code}@nexus302.systems.uk.hsbc:8081/nexus/repository
proxy_servers:
  https: ${httpprox}
  http: ${httpprox}
EOM
#######rename default python3 kernel to Python3.8
cat > /opt/conda/miniconda3/share/jupyter/kernels/python3/kernel.json << EOM
{
  "argv": [
    "/opt/conda/miniconda3/bin/python",
    "-m",
    "ipykernel_launcher",
    "-f",
    "{connection_file}"
  ],
"display_name": "Python3.8",
  "language": "python",
  "metadata": {
  "debugger": true
   },
  "env": {
    "PYSPARK_PYTHON": "/opt/conda/miniconda3/bin/python",
    "SPARK_HOME": "/usr/lib/spark"
  }
}
EOM
/opt/conda/default/bin/pip install jupyter-resource-usage==0.6.1 --proxy ${httpprox} --index-url=${nexus_index_url} --trusted-host=${nexus_host}
