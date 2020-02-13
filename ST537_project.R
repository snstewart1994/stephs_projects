# working directory
setwd("C:/Users/aalna/Desktop/ST 537/ST537Project")

# Read the data from the raw file
library(readxl)
admission_data <- read_excel("App_data (1).xlsx")
applicant.num=read.delim("applicant_num.txt")
colnames(applicant.num)=c("HS_GPA","HS_GPA_UWH","SATM","SATV","SAT_TOTAL","ACTC","HSPCT","trf_credits")

attach(applicant.num)

# data sets for FA

dat1=cbind(HS_GPA_UWH,SAT_TOTAL,ACTC,HSPCT,trf_credits)

#Normalize the dataset
std.dat1=scale(dat1,center = T,scale = T)
# PCA 

pca.dat1=prcomp(std.dat1)
pca.dat1

# Visualizing correlation
library(GGally)
ggcorr(dat1,label_size = 6,label_round = 2,label = T)


library(corrplot)

corrplot(cor(dat1),order='hclust')


# three factor model which is not valid
#out.31 <- factanal(std.dat1, factors = 3)

# two factor model
out.21 <- factanal(std.dat1, factors = 2)
out.21


# CFA for hypothesized Model for 2 factor

library(sem)
admission_model <- specifyModel(file = "model.fit.txt")
admission_model1 <- specifyModel(file = "model.fit1.txt")
model.data=data.frame(std.dat1)
model.fit <- sem::sem(model = admission_model,  
                        data=model.data,   
                        N = 17417 )
model.fit1 <- sem::sem(model = admission_model1,  
                      data=model.data,   
                      N = 17417 )
summary(model.fit)
summary(model.fit1)

# It seems the both model fit is not significant. p<0.05

# Even the model is not significant, I build the relational chart
library(DiagrammeR)
pathDiagram(model.fit,     
            ignore.double = FALSE,  
            edge.labels = "both",   
            file = "modelfit",  
            output.type = "dot",
            node.colors = c("blue", "green"))  ## Node colors

pathDiagram(model.fit1,     
            ignore.double = FALSE,  
            edge.labels = "both",   
            file = "modelfit1",  
            output.type = "dot",
            node.colors = c("blue", "green"))  ## Node colors


# Plot the estimated graph
grViz("modelfit.dot")
grViz("modelfit1.dot")

detach(applicant.num)

# Summary Stats

library(ICSNP)

# GPA in diff. groups

par(mfrow=c(1,3))
boxplot(HS_GPA_UWH ~ gender, data = admission_data, 
        xlab = "Gender",
        ylab = "GPA", notch=TRUE,
        col = c("green","blue"),names=c("Female","Male"))

t.test(HS_GPA_UWH ~ gender,data = admission_data,var.equal=T)
t.test(admission_data$HS_GPA_UWH)
par(mfrow=c(1,3))
boxplot(HS_GPA_UWH ~ grad_years, data = admission_data, 
        xlab = "Time to Graduation",
        ylab = "GPA", notch=TRUE,
        col = c("green","yellow","purple","blue"))

boxplot(HS_GPA_UWH ~ First_gen, data = admission_data, 
        xlab = "First Generation",
        ylab = "GPA", notch=TRUE,
        col = c("green","blue"),names=c("No","Yes"))

t.test(HS_GPA_UWH ~ First_gen,data = admission_data,var.equal=T)
boxplot(HS_GPA_UWH ~ First_gen, data = admission_data,
        xlab = "Fall Term",
        ylab = "ACT Score", 
        notch=TRUE,main="ACTC",
        col = c("green","blue"))
boxplot(HS_GPA_UWH ~ grad_years, data = admission_data,
        xlab = "Fall Term",
        ylab = "ACT Score", 
        notch=TRUE,main="ACTC",
        col = c("green","blue"))

# SAT and ACT in groups

boxplot(SAT_TOTAL ~ grad_years, data = admission_data, 
        xlab = "Time to Graduation",
        ylab = "SAT", notch=TRUE,
        col = c("green","yellow","purple","blue"))
boxplot(ACTC ~ grad_years, data = admission_data, 
        xlab = "Time to Graduation",
        ylab = "ACT", notch=TRUE,
        col = c("green","yellow","purple","blue"))

gpa.year=aov(HS_GPA_UWH ~ grad_years, data = admission_data,na.action=na.omit)
gpa.year
TukeyHSD(gpa.year)


par(mfrow=c(1,2))
boxplot(SAT_TOTAL ~ gender, data = admission_data,
        xlab = "Gender",
        ylab = "SAT_TOTAL", 
        main = "SAT Score Comparison",
        col = c("green","blue"),notch=TRUE
)
boxplot(ACTC ~ gender, data = admission_data,
        xlab = "Gender",
        ylab = "ACT Score", 
        main = "ACT Score Comparison",notch=TRUE,
        col = c("green","blue"))
t.test(SAT_TOTAL ~ gender,data = admission_data,var.equal=T)
t.test(ACTC ~ gender,data = admission_data,var.equal=T)


# Trend in GPA, ACT and SAT over time

par(mfrow=c(1,3))
boxplot(HS_GPA_UWH ~ TERM, data = admission_data,
        xlab = "Fall Term",
        ylab = "GPA", main="GPA",
        notch=TRUE,
        col = c("green","blue","purple","orange"),names=c("09","10","11","12"))

boxplot(SAT_TOTAL ~ TERM, data = admission_data,
        xlab = "Fall Term",
        ylab = "SAT Score", 
        notch=TRUE,main="SAT",
        col = c("green","blue","purple","orange"),names=c("09","10","11","12"))

boxplot(ACTC ~ TERM, data = admission_data,
        xlab = "Fall Term",
        ylab = "ACT Score", 
        notch=TRUE,main="ACTC",
        col = c("green","blue","purple","orange"),names=c("09","10","11","12"))
summary(admission_data)

#PCA
std.dat <- scale(applicant.num, center = T, scale = T)
data.pca <- prcomp(std.dat)
summary(data.pca)

# char data
applicant_char <- read.delim("C:/Users/aalna/Desktop/ST 537/ST537Project/applicant_char.txt")
lambda <- data.pca$sdev^2

# scree plots
par(mfrow = c(1,2))
plot(lambda, type="b", pch = 19, main = "Variance explained by each PC",
     xlab = "PC number", ylab = "Variance explained")

plot(log(lambda), type="b", pch = 19, main = "log(variance) explained by each PC",
     xlab = "PC number", ylab = "log(variance) explained")

data.pca$rotation[, 1:3]


#classification
applicant.pca <- cbind(applicant.char,data.pca$x[, 1:3])

coll <- as.factor(applicant.pca$college)
gen <- as.factor(applicant.pca$gender)
fg <- as.factor(applicant.pca$First_gen)
res <- as.factor(applicant.pca$First_gen)
applicant.pca$Tier_Designation[is.na(applicant.pca$Tier_Designation)] <- 0
tier <- as.factor(applicant.pca$Tier_Designation)
min <- as.factor(applicant.pca$underrepresented_minority)
pc1 <- applicant.pca$PC1
pc2 <- applicant.pca$PC2
pc3 <- applicant.pca$PC3
grad <- as.factor(applicant.pca$grad_years)
grad1 <- as.factor(ifelse(applicant.pca$grad_years == 0,0,1))

classification <- data.frame(grad,coll,gen,fg,tier,min,pc1,pc2,pc3)
library(caret)
set.seed(1)
# indices for the training data
trainIndex <- createDataPartition(y = classification$grad, 
                                  p = .8, 
                                  list = FALSE, 
                                  times = 1)
# Training and test sets
train <- classification[ trainIndex,]
Test  <- classification[-trainIndex,]

TrControl <- trainControl(method = "repeatedcv",
                          number = 10, #10-fold CV
                          repeats = 30 # number of repeats
)
trainplot <- data.frame(train$coll,train$gen,train$fg,train$tier,train$min,train$pc1,train$pc2,train$pc3)
p1 <- featurePlot(x = trainplot, 
                  y = train$grad1, 
                  plot = "pairs",
                  ## Add a key at the top
                  auto.key = list(columns = 3))
p1

# SVM fit
#Model.svm <- train(grad ~ ., data = train, 
#                   method = "svmRadial", 
#                   trControl = TrControl,
#                   tuneLength = 10)
#KNN fit
Model.knn <- train(grad ~ ., data = train, 
                   method = "knn", 
                   trControl = TrControl,
                   tuneLength = 10)
# LDA fit
Model.lda <- train(grad ~ ., data = train, 
                   method = "lda", 
                   trControl = TrControl,
                   tuneLength = 10)
# QDA fit
Model.qda <- train(grad ~ ., data = train, 
                   method = "qda", 
                   trControl = TrControl,
                   tuneLength = 10)
# Rpart fit
Model.rpart <- train(grad ~ ., data = train, 
                     method = "rpart", 
                     trControl = TrControl,
                     tuneLength = 10)

# Extract the resamples from all the four models
resamp <- resamples(list(#SVM = Model.svm, 
  LDA = Model.lda, 
  QDA = Model.qda,
  KNN = Model.knn, 
  RPART = Model.rpart))

summary(resamp)
bwplot(resamp)
difValues <- diff(resamp)
dotplot(difValues)

pred.rpart <- predict(Model.rpart, Test)
postResample(pred = pred.rpart, obs = Test$grad)

pred.lda <- predict(Model.lda, Test)
postResample(pred = pred.lda, obs = Test$grad)

pred.knn <- predict(Model.knn, Test)
postResample(pred = pred.knn, obs = Test$grad)

# confusion matrices
confusionMatrix(data = pred.rpart, reference = Test$grad)
confusionMatrix(data = pred.lda, reference = Test$grad)

quit()
