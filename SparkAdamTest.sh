# Exact command for starting cluster and testing performance

# Update / reinstall Eggo to the latest version:
pip install  --ignore-installed  git+https://github.com/bigdatagenomics/eggo.git

# Set the Amazon keys environment
source ~/amazon_keys/export_variables.sh

# Start up the cluster (takes 45 minutes)
eggo-cluster provision -n 11 --worker-instance-type m3.xlarge --stack-name adamTest1

#login to the cluster
eggo-cluster login --stack-name adamTest1

# Get s3cmd
wget https://github.com/s3tools/s3cmd/archive/master.zip
unzip master.zip

# Set amazon acces keys
./s3cmd-master/s3cmd --configure

# Create directory for 1kg vcf file(s)
mkdir 1kg
cd 1kg

# Download chr 22
/home/ec2-user/s3cmd-master/s3cmd  get s3://1000genomes/release/20130502/ALL.chr22.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.vcf.gz

# Create 1kg dir on hdfs
hadoop fs -mkdir /user/ec2-user/1kg

# Copy to hdfs
zcat /home/ec2-user/1kg/ALL.chr22.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.vcf.gz | hadoop fs -put -  /user/ec2-user/1kg/chr22.vcf

# Go to the adam directory
cd /home/ec2-user/adam/bin/

# Convert vcf file to adam/parquet format (18 minutes)
./adam-submit --master yarn-client --driver-memory 8g --num-executors 11 --executor-cores 4 --executor-memory 12531875840 -- vcf2adam -parquet_compression_codec SNAPPY   /user/ec2-user/1kg/chr22.vcf /user/ec2-user/1kg/chr22.adam

#15/11/10 11:54:02 INFO DAGScheduler: Stage 0 (saveAsNewAPIHadoopFile at ADAMRDDFunctions.scala:75) finished in 1080.302  


# Count genotypes in the Adam shell
./adam-shell --master yarn-client --driver-memory 8g --num-executors 11 --executor-cores 4 --executor-memory 12531875840

# Confirm the level of parallelism 
sc.defaultParallelism
res0: Int = 40

# Import the AdamContext and the avro schemas
import org.bdgenomics.adam.rdd.ADAMContext
import org.bdgenomics.formats.avro._

# Create the AdamContext
val ac = new ADAMContext(sc)

# Define the genotypes RDD
val genotypes  = ac.loadGenotypes("/user/ec2-user/1kg/chr22.adam")

#count the genotypes (8 minutes)
genotypes.count 

#15/11/10 12:10:08 INFO DAGScheduler: Stage 0 (count at <console>:30) finished in 485.205 s



# install bcftools
cd /home/ec2-user/
mkdir bcftools
cd bcftools
wget https://github.com/samtools/bcftools/releases/download/1.2/bcftools-1.2.tar.bz2
tar -jxvf bcftools-1.2.tar.bz2
cd bcftools-1.2
make


# Install htslib
cd /home/ec2-user/
mkdir htslib
cd htslib
wget https://github.com/samtools/htslib/releases/download/1.2.1/htslib-1.2.1.tar.bz2
tar -jxvf htslib-1.2.1.tar.bz2
cd htslib-1.2.1
make

# convert vcf file to bcf
cd /home/ec2-user/1kg/
/home/ec2-user/htslib/htslib-1.2.1/tabix ALL.chr22.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.vcf.gz
/home/ec2-user/bcftools/bcftools-1.2/bcftools view ALL.chr22.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.vcf.gz -O z > ALL.chr22.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.bcf


time /home/ec2-user/bcftools/bcftools-1.2/bcftools view  ALL.chr22.phase3_shapeit2_mvncall_integrated_v5a.20130502.genotypes.bcf | wc -l
#1103803

#real    5m7.310s
#user    4m46.348s
#sys     0m59.529s
