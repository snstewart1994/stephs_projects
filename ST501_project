###
# Stephanie Stewart
# 2019-07-24
###

set.seed(1978)


# Problem 5.
N=50
#N=10000

#Simulate 50/10000 samples of size 1000,10000 from N(mu,sigma) distribution
n<-c(1000,10000)

#b as in problem 1.
b <- 5
#using expected value and variance from problem 3.
mu<-2*b^2
sigma<-sqrt(20*b^4)

#list to save data values in
data<-list()
for(i in 1:length(n)){data[[i]]<-matrix(0,nrow=N,ncol=n[i])}

#Create the data#loop over sample sizes
for (j in 1:length(n)){
  #loop over data sets
  for (i in 1:N){data[[j]][i,]<-rnorm(n=n[j],mean=mu,sd=sigma)}
  }

#calculate the z statistic for each sample
means1000<-apply(X=data[[1]],FUN=function(data){(mean(data)-mu)/(sigma/sqrt(n[1]))},MARGIN=1)
means10000<-apply(X=data[[2]],FUN=function(data){(mean(data)-mu)/(sigma/sqrt(n[2]))},MARGIN=1)

# Problem 6.
hist(means1000,main=paste("Histogram of z's with ",N," samples, n=1,000 from N(",mu,",",sigma^2,")",sep=""),prob=T)
lines(seq(from=-3,to=3,by=0.01),dnorm(seq(from=-3,to=3,by=0.01)))
hist(means10000,main=paste("Histogram of z's with ",N," samples, n=10,000 from N(",mu,",",sigma^2,")",sep=""),prob=T)
lines(seq(from=-3,to=3,by=0.01),dnorm(seq(from=-3,to=3,by=0.01)))

#Using N=50, while the samples seem to be converging to normal, they still do not appear quite normal even for sample size n=10,000
#When we change to N=10,000 both n=1,000 and n=10,000 appear normal
#This shows it is not enough for n>30 the number of sample repetitions also plays a role in CLT.
