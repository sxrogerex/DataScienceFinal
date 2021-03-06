# Load packages
library(shiny)
library('ggplot2') #visualization
library('ggthemes') # visualization
library('gridExtra') # visualization
library('grid') # visualization
library("Hmisc") # correlation
library("reshape2") # correlation

#read file
data <- read.csv("data.csv", header = T, stringsAsFactors = F)

shinyServer(function(input, output, session) {
  set.seed(101)
  #Visualization
  #Willing to pay how much money to buy fast fashion clothes?
  willToPay <- matrix(0, 6,1)
  colnames(willToPay) = c("Average ($)")
  rownames(willToPay) = c("Short Sleeve","Long-sleeved Shirt","Shorts","Trousers","Hoodies","Coat")
  willToPay[,] = round(c(mean(data[,5]),mean(data[,6]),mean(data[,7]),mean(data[,8]),mean(data[,9]),mean(data[,10])),0)
  output$willPay <- renderPlot({
    grid.arrange(
      textGrob("Willing to pay how much money to buy fast fashion clothes?", 
               vjust=0, gp=gpar(fontsize=20)),
      tableGrob(willToPay),
      nrow=2)
    })
    #Purchasing frequency and Sex
    output$freqSex <- renderPlot({
      ggplot(data = data) + 
      geom_bar(mapping = aes(x = factor(data[,4]), fill = factor(Sex)))+ 
      labs(x = "Period", title="The frequency of purchasing",subtitle= "fast fashsion clothes")+
      scale_x_discrete( breaks = c("0","1","4","12","24","30"), labels=c("Not sure","1 week","1 month","3 month","6 month",">6month"))
    })
    #Income and Sex
    output$incomeSex <- renderPlot({
    ggplot(data = data) + 
      geom_bar(mapping = aes(x = factor(data[,65]), fill = factor(Sex)))+ 
      labs(x = "Income", title="Income and Sex")+
      scale_x_discrete( breaks = c("2500","7500","12500","17500","25000"), labels=c("0~5000","5000~10000","10000~15000","15000~20000","20000~"))
    })
    
    #Spearman rank correlation
    spearman <- data[,5:10]
    spearman[,7] <- data[,4]
    spearman[,8] <- data[,65]
    spearman[,9] <- data[,63]
    colnames(spearman) <- c("Short Sleeve","Long-sleeved Shirt","Shorts","Trousers","Hoodies","Coat","frequency","Income","Sex")
    abbreviateSTR <- function(value, prefix){  # format string more concisely
      lst = c()
      for (item in value) {
        if (is.nan(item) || is.na(item)) { # if item is NaN return empty string
          lst <- c(lst, '')
          next
        }
        item <- round(item, 2) # round to two digits
        if (item == 0) { # if rounding results in 0 clarify
          item = '<.01'
        }
        item <- as.character(item)
        item <- sub("(^[0])+", "", item)    # remove leading 0: 0.05 -> .05
        item <- sub("(^-[0])+", "-", item)  # remove leading -0: -0.05 -> -.05
        lst <- c(lst, paste(prefix, item, sep = ""))
      }
      return(lst)
    }
    
    cormatrix <- rcorr(as.matrix(spearman), type='spearman')
    cordata = melt(cormatrix$r)
    cordata$labelr = abbreviateSTR(melt(cormatrix$r)$value, 'r')
    cordata$labelP = abbreviateSTR(melt(cormatrix$P)$value, 'P')
    cordata$label = paste(cordata$labelr, "\n", 
                          cordata$labelP, sep = "")
    cordata$strike = ""
    cordata$strike[cormatrix$P > 0.05] = "X"
    
    txtsize <- par('din')[2] / 2
    output$spearman <- renderPlot({
      ggplot(cordata, aes(x=Var1, y=Var2, fill=value)) + geom_tile() + 
      theme(axis.text.x = element_text(angle=90, hjust=TRUE)) +
      xlab("") + ylab("") + 
      geom_text(label=cordata$label, size=txtsize) + 
      geom_text(label=cordata$strike, size=txtsize * 4, color="red", alpha=0.4)
    })
      #p of frequency all > 0.05, can't reject h0
    #all p between income and other clothes < 0.05, reject h0 
    #but correlation coefficient all between 0.16~0.25, Modestly correlated
    #all p between sex and other clothes < 0.05, reject h0 
    #but correlation coefficient all between 0.20~0.34, Modestly correlated
    
    #Data
    output$data <- renderTable({
      spearman
    })
    
    #Linear regression, k fold validation
    #Setting before splitting data
    k=5
    folds <- cut(seq(1,nrow(data)),breaks=k,labels=FALSE)
    folds <- sample(folds, nrow(data))
    p1 <- data.frame()
    p2 <- data.frame()
    p3 <- data.frame()
    p4 <- data.frame()
    p5 <- data.frame()
    p6 <- data.frame()
    r1 <- c()
    r1 <- c()
    r2 <- c()
    r3 <- c()
    r4 <- c()
    r5 <- c()
    r6 <- c()
    for(i in 1:k) {
      # actual split of the data
      fold.test <- which(folds == i)
      if(i<k){
        fold.valid <- which(folds == i+1)
        fold.train <- which((folds != i) & (folds!=i+1))
      }else{
        fold.valid <- which(folds == 1)
        fold.train <- which((folds != i) & (folds!=1))
      }
      data.train <- data[fold.train,]
      data.test <- data[fold.test,]
      data.valid <- data[fold.valid,]
      # train and test the model
      L1 <- lm(formula = short_sleeve~factor(Sex)+Income,data = data.train)
      L2 <- lm(formula = long_sleeved_shirt~factor(Sex)+Income,data = data.train)
      L3 <- lm(formula = shorts~factor(Sex)+Income,data = data.train)
      L4 <- lm(formula = trousers~factor(Sex)+Income,data = data.train)
      L5 <- lm(formula = hoodies~factor(Sex)+Income,data = data.train)
      L6 <- lm(formula = coat~factor(Sex)+Income,data = data.train)
      r1[i] <- summary(L1)$adj.r.squared
      r2[i] <- summary(L2)$adj.r.squared
      r3[i] <- summary(L3)$adj.r.squared
      r4[i] <- summary(L4)$adj.r.squared
      r5[i] <- summary(L5)$adj.r.squared
      r6[i] <- summary(L6)$adj.r.squared
      p1[i,1] <- round(summary(L1)$coef[2,"Pr(>|t|)"],4)
      p1[i,2] <- round(summary(L1)$coef[3,"Pr(>|t|)"],4)
      p2[i,1] <- round(summary(L2)$coef[2,"Pr(>|t|)"],4)
      p2[i,2] <- round(summary(L2)$coef[3,"Pr(>|t|)"],4)
      p3[i,1] <- round(summary(L3)$coef[2,"Pr(>|t|)"],4)
      p3[i,2] <- round(summary(L3)$coef[3,"Pr(>|t|)"],4)
      p4[i,1] <- round(summary(L4)$coef[2,"Pr(>|t|)"],4)
      p4[i,2] <- round(summary(L4)$coef[3,"Pr(>|t|)"],4)
      p5[i,1] <- round(summary(L5)$coef[2,"Pr(>|t|)"],4)
      p5[i,2] <- round(summary(L5)$coef[3,"Pr(>|t|)"],4)
      p6[i,1] <- round(summary(L6)$coef[2,"Pr(>|t|)"],4)
      p6[i,2] <- round(summary(L6)$coef[3,"Pr(>|t|)"],4)
    }
    colnames(p1) <- c("pOfSex","pOfIncome")
    colnames(p2) <- c("pOfSex","pOfIncome")
    colnames(p3) <- c("pOfSex","pOfIncome")
    colnames(p4) <- c("pOfSex","pOfIncome")
    colnames(p5) <- c("pOfSex","pOfIncome")
    colnames(p6) <- c("pOfSex","pOfIncome")
    
    output$trainResult <- renderTable({data.frame(shortSleeveActual=data.train$short_sleeve,shortSleevePredict=fitted(L1),longSleeveActual=data.train$long_sleeved_shirt,longSleevePredict=fitted(L2),shortsActual=data.train$shorts,shortsPredict=fitted(L3),trousersActual=data.train$trousers,trousersPredict=fitted(L4),hoodiesActual=data.train$hoodies,hoodiesPredict=fitted(L5),coatActual=data.train$coat,coatPredict=fitted(L6))})
    output$validResult <- renderTable({data.frame(shortSleeveActual=data.valid$short_sleeve,shortSleevePredict=predict(L1,data.valid,type="response"),longSleeveActual=data.valid$long_sleeved_shirt,longSleevePredict=predict(L2,data.valid,type="response"),shortsActual=data.valid$shorts,shortsPredict=predict(L3,data.valid,type="response"),trousersActual=data.valid$trousers,trousersPredict=predict(L4,data.valid,type="response"),hoodiesActual=data.valid$hoodies,hoodiesPredict=predict(L5,data.valid,type="response"),coatActual=data.valid$coat,coatPredict=predict(L6,data.valid,type="response"))})
    output$testResult <- renderTable({data.frame(shortSleeveActual=data.test$short_sleeve,shortSleevePredict=predict(L1,data.test,type="response"),longSleeveActual=data.test$long_sleeved_shirt,longSleevePredict=predict(L2,data.test,type="response"),shortsActual=data.test$shorts,shortsPredict=predict(L3,data.test,type="response"),trousersActual=data.test$trousers,trousersPredict=predict(L4,data.test,type="response"),hoodiesActual=data.test$hoodies,hoodiesPredict=predict(L5,data.test,type="response"),coatActual=data.test$coat,coatPredict=predict(L6,data.test,type="response"))})
     
    #Table of p
    output$p <- renderPlot({
    grid.arrange(
      textGrob("", 
               vjust=0, gp=gpar(fontsize=20)),
      textGrob("P value of different model in each fold", 
               vjust=0, gp=gpar(fontsize=20)),
      textGrob("", 
               vjust=0, gp=gpar(fontsize=20)),
      tableGrob(p1),
      tableGrob(p2),
      tableGrob(p3),
      tableGrob(p4),
      tableGrob(p5),
      tableGrob(p6),
      nrow=3)})
    
    #Table of R square
    rSquare <- matrix(0, 6,k)
    colnames(rSquare) <- c(1:k)
    rownames(rSquare) <- c("Short Sleeve","Long-sleeved Shirt","Shorts","Trousers","Hoodies","Coat")
    rSquare[1,1:k] = r1
    rSquare[2,1:k] = r2
    rSquare[3,1:k] = r3
    rSquare[4,1:k] = r4
    rSquare[5,1:k] = r5
    rSquare[6,1:k] = r6
    rSquare <- round(rSquare,2)
    output$r <- renderPlot({
    grid.arrange(
      textGrob("R square of different model in each fold", 
               vjust=0, gp=gpar(fontsize=16)),
      tableGrob(rSquare),
      nrow=2)})

})